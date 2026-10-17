// TUKTUK WebApp: camera preview with guides. Keeps the full photo without cropping.
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

  let active = false;

  window.tuktukGuidedCapturePhoto = async function (kind) {
    const guide = guides[kind];
    if (!guide || active) throw new Error('GUIDED_CAMERA_UNAVAILABLE');
    if (!window.isSecureContext || !navigator.mediaDevices ||
        !navigator.mediaDevices.getUserMedia) {
      throw new Error('GUIDED_CAMERA_NOT_SUPPORTED');
    }

    active = true;
    return new Promise(function (resolve, reject) {
      let stream = null;
      let settled = false;
      let captured = null;
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
      panel.appendChild(heading);
      panel.appendChild(instructions);
      panel.appendChild(stage);
      panel.appendChild(status);
      panel.appendChild(actions);
      dialog.appendChild(panel);

      function onKey(event) {
        if (event.key === 'Escape') finish(null);
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
          const canvas = document.createElement('canvas');
          const scale = Math.min(1, 2048 / Math.max(video.videoWidth, video.videoHeight));
          canvas.width = Math.max(1, Math.round(video.videoWidth * scale));
          canvas.height = Math.max(1, Math.round(video.videoHeight * scale));
          const ctx = canvas.getContext('2d');
          if (!ctx) throw new Error('CANVAS_UNAVAILABLE');
          ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
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
        primary.disabled = false;
        status.textContent = 'Alinea el documento o vehículo y pulsa Tomar foto.';
      }).catch(function () {
        if (settled) return;
        status.textContent = 'No se pudo abrir la cámara. Cancela y elige una foto de la galería.';
        primary.disabled = true;
      });
    });
  };
})();
