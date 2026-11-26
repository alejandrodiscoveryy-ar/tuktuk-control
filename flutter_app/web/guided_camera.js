// TUKTUK WebApp: camera preview with guides. Saves exactly what is inside the green frame.
// Camera frames stay in the browser until the driver confirms the image.
(function () {
  'use strict';

  const guides = {
    driver: {
      title: 'Fotografía del conductor',
      help: 'Centra el rostro en el óvalo, mira de frente y deja espacio sobre la cabeza. Usa buena iluminación.',
      ratio: '1 / 1',
      aspect: 1,
      label: 'Guía de rostro y hombros',
      prompt: 'Centra tu rostro dentro del óvalo.',
      facing: 'user'
    },
    'identity-front': {
      title: 'Documento · Parte delantera',
      help: 'Coloca el carné o la licencia completa dentro del marco. Evita reflejos.',
      ratio: '1.59 / 1',
      aspect: 1.59,
      prompt: 'Deja las cuatro esquinas dentro del marco.',
      facing: 'environment',
      label: 'Guía para la cara delantera del carné'
    },
    'identity-back': {
      title: 'Documento · Parte trasera',
      help: 'Encuadra la cara trasera del documento. Comprueba que los datos se puedan leer.',
      ratio: '1.59 / 1',
      aspect: 1.59,
      prompt: 'Deja las cuatro esquinas dentro del marco.',
      facing: 'environment',
      label: 'Guía para la cara trasera del carné'
    },
    vehicle: {
      title: 'Fotografía del vehículo',
      help: 'Aléjate hasta ver el vehículo completo, incluidas las ruedas. Busca buena iluminación.',
      ratio: '4 / 3',
      aspect: 4 / 3,
      prompt: 'Deja margen alrededor del vehículo y las ruedas.',
      facing: 'environment',
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

  function cameraFacing(track) {
    const facing = typeof track.getSettings === 'function'
      ? track.getSettings().facingMode : undefined;
    if (facing === 'user' || facing === 'environment') return facing;
    const label = track.label || '';
    if (/front|selfie|frontal|delantera|facetime/i.test(label)) return 'user';
    if (/back|rear|environment|trasera|posterior/i.test(label)) return 'environment';
    return 'unknown';
  }

  function stopCamera(cameraStream) {
    if (cameraStream) cameraStream.getTracks().forEach(track => track.stop());
  }

  // A mere ideal preference can return the last-used rear camera.
  async function requestDriverCamera(media, stillOpen, desired = 'user') {
    // Some mobile browsers cannot satisfy exact facingMode or do not expose
    // facingMode in getSettings. Keep a working guided preview in that case.
    const dimensions = { width: { ideal: 1280 }, height: { ideal: 720 } };
    const opposite = desired === 'user' ? 'environment' : 'user';
    async function request(constraint, rejectOpposite) {
      if (!stillOpen()) throw new Error('CAMERA_CLOSED');
      const result = await media.getUserMedia({ audio: false, video: { ...dimensions, ...constraint } });
      const track = result.getVideoTracks()[0];
      if (!stillOpen() || !track || (rejectOpposite && cameraFacing(track) === opposite)) {
        stopCamera(result);
        throw new Error('CAMERA_LENS_UNAVAILABLE');
      }
      return result;
    }
    function fatal(error) {
      return !stillOpen() || error.name === 'NotAllowedError' || error.name === 'SecurityError';
    }
    try {
      return await request({ facingMode: { exact: desired } }, true);
    } catch (error) {
      if (fatal(error)) throw error;
    }
    const cameras = typeof media.enumerateDevices === 'function'
      ? await media.enumerateDevices().catch(() => []) : [];
    const pattern = desired === 'user' ? /front|selfie|frontal|delantera|facetime/i
      : /back|rear|environment|trasera|posterior/i;
    const matching = cameras.find(device => device.kind === 'videoinput' &&
      device.deviceId && pattern.test(device.label || ''));
    if (matching) {
      try {
        return await request({ deviceId: { exact: matching.deviceId } }, true);
      } catch (error) {
        if (fatal(error)) throw error;
      }
    }
    // An ideal request may return an unknown or alternate lens. The user
    // can switch within the live guide instead of losing the camera entirely.
    try {
      return await request({ facingMode: { ideal: desired } }, false);
    } catch (error) {
      if (fatal(error)) throw error;
    }
    if (!stillOpen()) throw new Error('CAMERA_CLOSED');
    const result = await media.getUserMedia({ audio: false, video: true });
    if (!stillOpen() || !result.getVideoTracks().length) {
      stopCamera(result);
      throw new Error('CAMERA_CLOSED');
    }
    return result;
  }

  // A Flutter Web surface can sit above a regular DOM overlay. The browser
  // top layer is independent of those stacking contexts. Only the selfie
  // uses it; the verified document and vehicle overlays stay unchanged.
  function showSelfieDialog(dialog) {
    if (typeof dialog.showModal !== 'function') return false;
    try {
      dialog.showModal();
      return dialog.open === true;
    } catch (_) {
      return false;
    }
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
      let requestedFacing = guide.facing;
      let openingCamera = false;
      let openedFacing = 'unknown';
      const previousOverflow = document.body.style.overflow;
      const dialog = make(kind === 'driver' ? 'dialog' : 'div', 'tuktuk-camera-dialog');
      if (kind === 'driver') dialog.classList.add('tuktuk-camera-selfie-dialog');
      dialog.setAttribute('role', 'dialog');
      dialog.setAttribute('aria-modal', 'true');
      dialog.setAttribute('aria-label', guide.title);
      dialog.tabIndex = -1;

      const panel = make('div', 'tuktuk-camera-panel');
      const heading = make('h2', 'tuktuk-camera-heading', guide.title);
      const instructions = make('p', 'tuktuk-camera-help', guide.help);
      const stage = make('div', 'tuktuk-camera-stage');
      stage.dataset.kind = kind;
      const video = make('video', 'tuktuk-camera-video');
      if (kind === 'driver') {
        video.setAttribute('playsinline', '');
        video.setAttribute('webkit-playsinline', '');
        video.setAttribute('muted', '');
      }
      video.autoplay = true;
      video.muted = true;
      video.playsInline = true;
      const image = make('img', 'tuktuk-camera-preview');
      image.alt = 'Fotografía tomada. Revisa los bordes antes de usarla.';
      image.hidden = true;
      const frame = make('div', 'tuktuk-camera-frame');
      frame.style.aspectRatio = guide.ratio;
      frame.style.setProperty('--guide-ratio', String(guide.aspect));
      frame.dataset.kind = kind;
      for (const position of ['tl', 'tr', 'bl', 'br']) {
        frame.appendChild(make('span', 'tuktuk-camera-corner ' + position));
      }
      if (kind === 'driver') {
        const face = make('span', 'tuktuk-camera-face-guide');
        face.appendChild(make('span', 'tuktuk-camera-eyeline'));
        frame.appendChild(face);
      }
      else frame.appendChild(make('span', 'tuktuk-camera-inner-guide'));
      frame.setAttribute('role', 'img');
      frame.setAttribute('aria-label', guide.label);
      const frameText = make('span', 'tuktuk-camera-frame-label',
        guide.prompt);
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
const fallback = make('button', 'tuktuk-camera-button tuktuk-camera-secondary', 'Cámara del teléfono');
      fallback.type = 'button';
      const switchLens = make('button', 'tuktuk-camera-button tuktuk-camera-secondary', 'Cambiar cámara');
      switchLens.type = 'button';
      switchLens.hidden = kind !== 'driver' || !canPreview;
      switchLens.disabled = true;
      actions.appendChild(switchLens);
      if (kind === 'driver') {
        fallback.textContent = 'Selfie con cámara del teléfono';
        fallback.hidden = true;
      }
      const picker = make('input', '');
      picker.type = 'file';
      picker.accept = 'image/*';
      picker.setAttribute('capture', guide.facing);
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
          captured = result.slice(result.indexOf(',') + 1);
          switchLens.hidden = true;
          image.src = result;
          image.hidden = false;
          video.hidden = true;
          frame.hidden = true;
          retake.hidden = false;
          primary.disabled = false;
          primary.textContent = 'Usar esta foto';
          status.textContent = 'Revisa que la fotografía sea nítida y completa.';
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
        if (kind === 'driver' && dialog.open && typeof dialog.close === 'function') dialog.close();
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
        primary.disabled = !ready;
        if (kind === 'driver' && canPreview) switchLens.hidden = false;
        status.textContent = ready ? guide.prompt + ' Pulsa Tomar foto.' : 'Reintenta la cámara o usa la opción del teléfono.';
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
          switchLens.hidden = true;
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
      if (kind === 'driver') {
        dialog.addEventListener('cancel', function (event) {
          event.preventDefault();
          if (!usingNative) finish(null);
        });
        dialog.addEventListener('close', function () {
          if (!settled) finish(null);
        });
        if (!showSelfieDialog(dialog)) {
          // Legacy browser: render as a regular open overlay rather than a
          // closed <dialog>, which is hidden by default.
          dialog.setAttribute('open', '');
        }
      }
      dialog.focus({ preventScroll: true });

      if (!canPreview) {
        fallback.hidden = false;
        status.textContent = kind === 'driver' ? 'Este navegador no permite el visor guiado. Usa la opción de selfie del teléfono.' : 'El visor no esta disponible. Pulsa Cámara del teléfono.';
        return;
      }
      async function openCamera(desired) {
        if (settled || openingCamera) return;
        openingCamera = true;
        requestedFacing = desired;
        ready = false;
        primary.disabled = true;
        switchLens.disabled = true;
        status.textContent = 'Abriendo la cámara…';
        stopCamera(stream);
        stream = null;
        video.srcObject = null;
        try {
          const cameraStream = kind === 'driver'
            ? await requestDriverCamera(navigator.mediaDevices, () => !settled, desired)
            : await navigator.mediaDevices.getUserMedia({
              audio: false,
              video: { facingMode: { ideal: guide.facing }, width: { ideal: 1920 }, height: { ideal: 1080 } }
            });
          if (settled) {
            stopCamera(cameraStream);
            return;
          }
          stream = cameraStream;
          openedFacing = cameraFacing(cameraStream.getVideoTracks()[0]);
          video.srcObject = cameraStream;
          await video.play();
          if (settled) return;
          ready = true;
          primary.disabled = false;
          if (captured === null) {
            status.textContent = kind === 'driver' && openedFacing === 'environment'
              ? 'Cámara trasera activa. Pulsa Cambiar cámara para intentar la frontal.'
              : guide.prompt + ' Pulsa Tomar foto.';
          }
          if (kind === 'driver') {
            switchLens.hidden = captured !== null;
            switchLens.textContent = 'Cambiar cámara';
            fallback.hidden = true;
          }
        } catch (_) {
          if (settled) return;
          stopCamera(stream);
          stream = null;
          video.srcObject = null;
          if (captured === null) {
            fallback.hidden = false;
            status.textContent = kind === 'driver'
              ? 'No se pudo abrir la cámara. Pulsa Reintentar cámara o usa la selfie del teléfono.'
              : 'El visor no se inició. Pulsa Cámara del teléfono o usa la galería.';
            primary.disabled = true;
            switchLens.textContent = 'Reintentar cámara';
          }
        } finally {
          openingCamera = false;
          if (!settled && kind === 'driver') switchLens.disabled = false;
        }
      }
      switchLens.addEventListener('click', function () {
        if (settled || openingCamera || captured !== null) return;
        const next = !ready ? 'user'
          : openedFacing === 'environment' ? 'user'
          : openedFacing === 'user' ? 'environment'
          : requestedFacing === 'user' ? 'environment' : 'user';
        openCamera(next);
      });
      if (kind === 'driver') {
        // Paint the top-layer UI before opening the camera. Even if lens
        // acquisition fails, the user sees the controls and error state.
        window.requestAnimationFrame(() => window.requestAnimationFrame(() => {
          if (!settled) openCamera(guide.facing);
        }));
      } else {
        openCamera(guide.facing);
      }
    });
  };
})();
