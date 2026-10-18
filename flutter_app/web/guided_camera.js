// TUKTUK WebApp: camera preview with guides. Saves exactly what is inside the green frame.
// Camera frames stay in the browser until the driver confirms the image.
(function () {
  'use strict';

  const guides = {
    'identity-front': {
      title: 'Carné de identidad · Delantera',
      help: 'Coloca el carné completo dentro del marco, con los cuatro bordes visibles. Evita reflejos.',
      ratio: '1.59 / 1',
      label: 'Guía para la cara delantera del carné'
    },
    'identity-back': {
      title: 'Carné de identidad · Trasera',
      help: 'Encuadra toda la cara trasera del carné. Comprueba que los datos se puedan leer.',
      ratio: '1.59 / 1',
      label: 'Guía para la cara trasera del carné'
    },
    vehicle: {
      title: 'Fotografía del vehículo',
      help: 'Aléjate hasta ver el vehículo completo, incluidas las ruedas. Busca buena iluminación.',
      ratio: '4 / 3',
      label: 'Guía para encuadrar el vehículo completo'
    }
  };

  function make(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text) element.textContent = text;
    return element;
  }

  // Convierte la guía visible a coordenadas reales de la cámara.
  function guideCropRect(video, frame) {
    const w = video.videoWidth;
    const h = video.videoHeight;
    const area = video.getBoundingClientRect();
    const guide = frame.getBoundingClientRect();
    if (![w, h, area.width, area.height, area.left, area.top,
          guide.left, guide.top, guide.width, guide.height].every(Number.isFinite) ||
        w < 1 || h < 1 || area.width < 1 || area.height < 1) {
      throw new Error('CAMERA_INVALID_GEOMETRY');
    }
    // El visor utiliza object-fit: cover, centrado.
    const zoom = Math.max(area.width / w, area.height / h);
    const imageLeft = area.left + (area.width - w * zoom) / 2;
    const imageTop = area.top + (area.height - h * zoom) / 2;
    const left = Math.max(guide.left, area.left);
    const top = Math.max(guide.top, area.top);
    const right = Math.min(guide.right, area.right);
    const bottom = Math.min(guide.bottom, area.bottom);
    if (!(right > left && bottom > top)) throw new Error('CAMERA_FRAME_OUTSIDE');
    const x = Math.max(0, (left - imageLeft) / zoom);
    const y = Math.max(0, (top - imageTop) / zoom);
    const width = Math.min(w - x, (right - left) / zoom);
    const height = Math.min(h - y, (bottom - top) / zoom);
    if (!(width >= 8 && height >= 8)) throw new Error('CAMERA_CROP_TOO_SMALL');
    return { x, y, width, height };
  }

  let active = false;

  window.tuktukGuidedCapturePhoto = async function (kind) {
    const guide = guides[kind];
    if (!guide || active) throw new Error('GUIDED_CAMERA_UNAVAILABLE');
    const canPreview = Boolean(window.isSecureContext &&
      navigator.mediaDevices && navigator.mediaDevices.getUserMedia);

    active = true;
    return new Promise(function (resolve, reject) {
      let stream = null;
      let settled = false;
      let captured = null;
      let ready = false;
      let usingNative = false;
      const previousOverflow = document.body.style.overflow;
      const dialog = make('div', 'tuktuk-camera-dialog');
      dialog.setAttribute('role', 'dialog');
      dialog.setAttribute('aria-modal', 'true');
      dialog.setAttribute('aria-label', guide.title);
      dialog.tabIndex = -1;

      const panel = make('div', 'tuktuk-camera-panel');
      const heading = make('h2', 'tuktuk-camera-heading', guide.title);
      const instructions = make('p', 'tuktuk-camera-help', guide.help);
      const stage = make('div', 'tuktuk-camera-stage');
      const video = make('video', 'tuktuk-camera-video');
      video.autoplay = true;
      video.muted = true;
      video.playsInline = true;
      const image = make('img', 'tuktuk-camera-preview');
      image.alt = 'Fotografía tomada. Revisa los bordes antes de usarla.';
      image.hidden = true;
      const frame = make('div', 'tuktuk-camera-frame');
      frame.style.aspectRatio = guide.ratio;
      frame.setAttribute('role', 'img');
      frame.setAttribute('aria-label', guide.label);
      const frameText = make('span', 'tuktuk-camera-frame-label',
        'Alinea los bordes dentro de esta guía');
      frame.appendChild(frameText);
      stage.appendChild(video);
      stage.appendChild(image);
      stage.appendChild(frame);

      const status = make('p', 'tuktuk-camera-status', 'Abriendo la cámara…');
      status.setAttribute('role', 'status');
      const actions = make('div', 'tuktuk-camera-actions');
      const cancel = make('button', 'tuktuk-camera-button tuktuk-camera-secondary', 'Cancelar');
      cancel.type = 'button';
      const retake = make('button', 'tuktuk-camera-button tuktuk-camera-secondary', 'Repetir foto');
      retake.type = 'button';
      retake.hidden = true;
      const primary = make('button', 'tuktuk-camera-button tuktuk-camera-primary', 'Tomar foto');
      primary.type = 'button';
      primary.disabled = true;
      actions.appendChild(cancel);
      actions.appendChild(retake);
      actions.appendChild(primary);
const fallback = make('button', 'tuktuk-camera-button tuktuk-camera-secondary', 'Camara del telefono');
      fallback.type = 'button';
      const picker = make('input', '');
      picker.type = 'file';
      picker.accept = 'image/*';
      picker.setAttribute('capture', 'environment');
      picker.hidden = true;
      actions.appendChild(fallback);
      actions.appendChild(picker);
      fallback.addEventListener('click', function () {
        if (settled) return;
        usingNative = true;
        picker.value = '';
        picker.click();
      });
      picker.addEventListener('cancel', function () { usingNative = false; });
      picker.addEventListener('change', function () {
        usingNative = false;
        if (settled || !picker.files || !picker.files[0]) return;
        const file = picker.files[0];
        if ((file.type && !file.type.startsWith('image/')) || file.size > 20 * 1024 * 1024) {
          status.textContent = 'Selecciona una foto valida de hasta 20 MB.';
          return;
        }
        const reader = new FileReader();
        reader.onload = function () {
          if (settled) return;
          const result = typeof reader.result === 'string' ? reader.result : '';
          if (!result.startsWith('data:image/') || !result.includes(',')) {
            status.textContent = 'No se pudo leer la foto.';
            return;
          }
          finish(result.slice(result.indexOf(',') + 1));
        };
        reader.onerror = function () {
          if (!settled) status.textContent = 'No se pudo leer la foto.';
        };
        reader.readAsDataURL(file);
      });
      panel.appendChild(heading);
      panel.appendChild(instructions);
      panel.appendChild(stage);
      panel.appendChild(status);
      panel.appendChild(actions);
      dialog.appendChild(panel);

      function onKey(event) {
        if (event.key === 'Escape' && ready && !usingNative) finish(null);
      }
      function finish(result, error) {
        if (settled) return;
        settled = true;
        active = false;
        if (stream) {
          stream.getTracks().forEach(function (track) { track.stop(); });
        }
        video.srcObject = null;
        document.removeEventListener('keydown', onKey);
        document.body.style.overflow = previousOverflow;
        dialog.remove();
        if (error) reject(error);
        else resolve(result);
      }

      cancel.addEventListener('click', function () { finish(null); });
      retake.addEventListener('click', function () {
        if (settled) return;
        captured = null;
        image.hidden = true;
        image.removeAttribute('src');
        video.hidden = false;
        frame.hidden = false;
        retake.hidden = true;
        primary.textContent = 'Tomar foto';
        status.textContent = 'Alinea el documento o vehículo y pulsa Tomar foto.';
      });
      primary.addEventListener('click', function () {
        if (settled || primary.disabled) return;
        if (captured !== null) {
          finish(captured);
          return;
        }
        if (!video.videoWidth || !video.videoHeight) {
          status.textContent = 'Espera a que la cámara esté lista.';
          return;
        }
        try {
          const crop = guideCropRect(video, frame);
          const canvas = document.createElement('canvas');
          const scale = Math.min(1, 2048 / Math.max(crop.width, crop.height));
          canvas.width = Math.max(1, Math.round(crop.width * scale));
          canvas.height = Math.max(1, Math.round(crop.height * scale));
          const ctx = canvas.getContext('2d');
          if (!ctx) throw new Error('CANVAS_UNAVAILABLE');
          ctx.drawImage(video, crop.x, crop.y, crop.width, crop.height,
            0, 0, canvas.width, canvas.height);
          const dataUrl = canvas.toDataURL('image/jpeg', 0.92);
          captured = dataUrl.split(',')[1];
          if (!captured) throw new Error('EMPTY_PHOTO');
          image.src = dataUrl;
          image.hidden = false;
          video.hidden = true;
          frame.hidden = true;
          retake.hidden = false;
          primary.textContent = 'Usar esta foto';
          status.textContent = 'Revisa que se vea todo y que la fotografía sea nítida.';
        } catch (_) {
          captured = null;
          status.textContent = 'No se pudo capturar. Repite la foto o usa la galería.';
        }
      });
      document.addEventListener('keydown', onKey);
      document.body.style.overflow = 'hidden';
      document.body.appendChild(dialog);
      dialog.focus();

      if (!canPreview) {
        status.textContent = 'El visor no esta disponible. Pulsa Camara del telefono.';
        return;
      }
      navigator.mediaDevices.getUserMedia({
        audio: false,
        video: { facingMode: { ideal: 'environment' }, width: { ideal: 1920 }, height: { ideal: 1080 } }
      }).then(async function (cameraStream) {
        if (settled) {
          cameraStream.getTracks().forEach(function (track) { track.stop(); });
          return;
        }
        stream = cameraStream;
        video.srcObject = cameraStream;
        await video.play();
        if (settled) return;
        ready = true;
        primary.disabled = false;
        status.textContent = 'Alinea el documento o vehículo y pulsa Tomar foto.';
      }).catch(function () {
        if (settled) return;
        if (stream) {
          stream.getTracks().forEach(function (track) { track.stop(); });
          stream = null;
          video.srcObject = null;
        }
        status.textContent = 'El visor no se inicio. Pulsa Camara del telefono o usa la galeria.';
        primary.disabled = true;
      });
    });
  };
})();
