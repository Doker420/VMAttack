(() => {
  const demoKey = 'poslaniya-demo-messages';
  const authKey = 'poslaniya-demo-auth';
  const retentionKey = 'poslaniya-daily-messages';
  const defaultMessages = [
    { text: 'Ты очень классно справляешься. Просто хотела, чтобы ты это знала 🤍', time: 'сегодня, 12:44', mood: 'pink', unread: true },
    { text: 'Кажется, ты мне нравишься. Давно хотел сказать.', time: 'вчера, 20:18', mood: 'yellow', unread: true },
    { text: 'Спасибо, что однажды поддержала меня. Я этого не забыл.', time: '12 марта, 09:02', mood: 'lilac', unread: false }
  ];

  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
  const getStoredMessages = () => {
    try { return JSON.parse(localStorage.getItem(demoKey)) || defaultMessages; } catch { return defaultMessages; }
  };
  let messages = getStoredMessages();
  let toastTimer;
  let pendingAuthProvider = null;
  let pendingAuthChallenge = null;
  let activeMessageId = null;
  const telegramWebApp = window.Telegram?.WebApp || null;
  const isTelegramWebApp = Boolean(telegramWebApp?.initData);

  async function apiRequest(path, options = {}) {
    try {
      const storedAuth = JSON.parse(localStorage.getItem(authKey) || 'null');
      const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
      if (storedAuth?.token) headers.Authorization = `Bearer ${storedAuth.token}`;
      if (telegramWebApp?.initData) headers['X-Telegram-Init-Data'] = telegramWebApp.initData;
      const response = await fetch(path, { ...options, headers });
      if (!response.ok) return { __error: true, status: response.status };
      return await response.json();
    } catch {
      return null;
    }
  }

  function showToast(text) {
    const toast = $('#toast');
    $('#toastText').textContent = text;
    toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove('show'), 2600);
  }

  function openDialog(id) {
    const dialog = document.getElementById(id);
    if (!dialog) return;
    // Native dialog keeps the focus and backdrop behavior accessible without a framework.
    if (!dialog.open) dialog.showModal();
  }

  function closeDialog(dialog) {
    if (dialog?.open) dialog.close();
  }

  function copyText(text, success = 'Ссылка скопирована') {
    if (navigator.clipboard?.writeText) {
      navigator.clipboard.writeText(text).then(() => showToast(success)).catch(() => showToast(text));
    } else {
      const helper = document.createElement('textarea');
      helper.value = text;
      helper.style.position = 'fixed';
      helper.style.opacity = '0';
      document.body.appendChild(helper);
      helper.select();
      try { document.execCommand('copy'); showToast(success); } catch { showToast(text); }
      helper.remove();
    }
  }

  function persistMessages() {
    localStorage.setItem(demoKey, JSON.stringify(messages));
  }

  function renderInbox() {
    const list = $('#inboxList');
    if (!list) return;
    if (!messages.length) {
      list.innerHTML = '<div class="empty-inbox"><span>♡</span><strong>Пока тихо</strong><small>Поделитесь ссылкой — и здесь появится первое послание.</small></div>';
    } else {
      list.innerHTML = messages.map((message) => `
        <article class="inbox-item ${message.unread ? 'unread' : ''}">
          <div class="message-avatar avatar-${message.mood || 'pink'}">${message.mood === 'yellow' ? '✦' : message.mood === 'lilac' ? '♡' : '?'}</div>
          <div class="inbox-message"><div><strong>Анонимно</strong><time>${message.time}</time></div><p>${escapeHtml(message.text)}</p><div class="message-actions"><button type="button" data-reveal-sender data-message-id="${message.id || ''}">Узнать отправителя · 7 ₽</button><button type="button" data-save>Сохранить</button></div></div>
          ${message.unread ? '<span class="unread-dot"></span>' : ''}
        </article>`).join('');
    }
    const count = $('#messageCount');
    const unread = $('#unreadCount');
    if (count) count.textContent = messages.length;
    if (unread) unread.textContent = messages.filter((message) => message.unread).length;
  }

  function renderWebAppInbox() {
    const list = $('#webappInbox');
    if (!list) return;
    const unreadMessages = messages.filter((message) => message.unread).length;
    if ($('#webappMessageCount')) $('#webappMessageCount').textContent = messages.length;
    if ($('#webappUnreadCount')) $('#webappUnreadCount').textContent = unreadMessages;
    if (!messages.length) {
      list.innerHTML = '<div class="webapp-empty">Пока тихо. Поделитесь ссылкой — и здесь появится первое послание ♡</div>';
      return;
    }
    list.innerHTML = messages.slice(0, 10).map((message) => `
      <article class="webapp-message ${message.unread ? 'unread' : ''}">
        <div class="message-avatar avatar-${message.mood || 'pink'}">${message.mood === 'yellow' ? '✦' : message.mood === 'lilac' ? '♡' : '?'}</div>
        <div class="webapp-message-body"><div class="webapp-message-meta"><strong>Анонимно</strong><time>${escapeHtml(message.time || 'недавно')}</time></div><p>${escapeHtml(message.text)}</p></div>
        ${message.unread ? '<span class="unread-dot"></span>' : ''}
      </article>`).join('');
  }

  async function syncInbox() {
    const result = await apiRequest('/api/v1/inbox');
    if (result?.messages) {
      messages = result.messages.map((message) => ({ ...message, time: message.time || new Date(message.createdAt).toLocaleString('ru-RU', { day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' }) }));
      persistMessages();
      renderInbox();
    }
    renderWebAppInbox();
    return result;
  }

  function escapeHtml(value) {
    return String(value).replace(/[&<>'"]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#039;', '"': '&quot;' }[char]));
  }

  async function submitAnonymousMessage(text) {
    const cleanText = text.trim();
    if (cleanText.length < 3) {
      showToast('Напишите хотя бы несколько слов');
      return false;
    }
    const result = await apiRequest('/api/v1/links/anya/messages', { method: 'POST', body: JSON.stringify({ text: cleanText, channel: 'web' }) });
    if (result?.__error && result.status >= 500) {
      showToast('Не удалось отправить. Попробуйте ещё раз');
      return false;
    }
    if (!result?.__error && result?.message) {
      await syncInbox();
    } else {
      messages.unshift({ id: `local-${Date.now()}`, text: cleanText, time: 'только что', mood: 'pink', unread: true });
      persistMessages();
      renderInbox();
      renderWebAppInbox();
    }
    return true;
  }

  async function openAuthFlow(provider) {
    pendingAuthProvider = provider;
    const pending = $('#authPending');
    const title = $('#authPendingTitle');
    const text = $('#authPendingText');
    const botLink = $('#authBotLink');
    if (!pending || !title || !text || !botLink) return;
    const isTelegram = provider === 'telegram';
    title.textContent = isTelegram ? 'Откройте Telegram-бота' : 'Откройте VK-бота';
    text.textContent = isTelegram ? 'Нажмите «Старт» в боте. После этого вернитесь сюда.' : 'Нажмите «Начать» в боте сообщества. После этого вернитесь сюда.';
    botLink.href = isTelegram ? 'https://t.me/poslaniya_demo_bot?start=auth_demo' : 'https://vk.me/poslaniya_demo';
    botLink.innerHTML = isTelegram ? 'Открыть Telegram-бота <span>↗</span>' : 'Открыть VK-бота <span>↗</span>';
    $('.auth-options')?.setAttribute('hidden', '');
    pending.hidden = false;
    openDialog('authDialog');
    const result = await apiRequest(`/api/v1/auth/${provider}/start`, { method: 'POST', body: JSON.stringify({}) });
    pendingAuthChallenge = result?.challenge || null;
    if (result?.botUrl) botLink.href = result.botUrl;
  }

  // All buttons that open a dialog use the same small event layer.
  document.addEventListener('click', (event) => {
    const openTrigger = event.target.closest('[data-open-dialog]');
    if (openTrigger) {
      event.preventDefault();
      const currentDialog = openTrigger.closest('dialog');
      const targetId = openTrigger.dataset.openDialog;
      if (targetId === 'authDialog') {
        $('.auth-options')?.removeAttribute('hidden');
        if ($('#authPending')) $('#authPending').hidden = true;
        if ($('#authCompleteButton')) $('#authCompleteButton').hidden = false;
      }
      if (currentDialog && currentDialog.id !== targetId) {
        closeDialog(currentDialog);
        requestAnimationFrame(() => openDialog(targetId));
      } else {
        openDialog(targetId);
      }
      $('.menu-toggle')?.setAttribute('aria-expanded', 'false');
      $('.desktop-nav')?.classList.remove('open');
      if (targetId === 'dashboardDialog') requestAnimationFrame(syncInbox);
      return;
    }
    const closeTrigger = event.target.closest('[data-close-dialog]');
    if (closeTrigger) {
      closeDialog(closeTrigger.closest('dialog'));
      return;
    }
    const integration = event.target.closest('[data-integration]');
    if (integration) {
      closeDialog($('#integrationDialog'));
      pendingAuthProvider = integration.dataset.integration === 'Telegram' ? 'telegram' : 'vk';
      openAuthFlow(pendingAuthProvider);
      return;
    }
    if (event.target.matches('.message-actions button')) {
      const button = event.target;
      const item = button.closest('.inbox-item');
      if (button.hasAttribute('data-reveal-sender')) {
        activeMessageId = button.dataset.messageId || null;
        openDialog('revealDialog');
        return;
      }
      if (button.hasAttribute('data-save')) {
        const messageIndex = [...document.querySelectorAll('.inbox-item')].indexOf(item);
        if (messages[messageIndex]) {
          messages[messageIndex].unread = false;
          persistMessages();
          if (messages[messageIndex].id && !String(messages[messageIndex].id).startsWith('local-')) {
            apiRequest(`/api/v1/messages/${messages[messageIndex].id}/save`, { method: 'POST', body: '{}' });
          }
        }
        item?.classList.remove('unread');
        item?.querySelector('.unread-dot')?.remove();
        renderInbox();
        showToast('Послание сохранено');
      }
    }
  });

  // Let a click on a dialog backdrop close it, but not a click inside the card.
  $$('dialog').forEach((dialog) => dialog.addEventListener('click', (event) => {
    if (event.target === dialog) closeDialog(dialog);
  }));

  $$('[data-auth-provider]').forEach((button) => button.addEventListener('click', () => openAuthFlow(button.dataset.authProvider)));

  $('#authCompleteButton')?.addEventListener('click', async () => {
    const provider = pendingAuthProvider || 'telegram';
    let result = pendingAuthChallenge ? await apiRequest(`/api/v1/auth/${provider}/status?challenge=${encodeURIComponent(pendingAuthChallenge)}`) : null;
    // Demo mode lets a reviewer complete the flow without a real bot. Production
    // returns 409 here until Telegram/VK webhook confirms the challenge.
    if (!result?.user && !result?.__error) result = await apiRequest(`/api/v1/auth/${provider}/complete`, { method: 'POST', body: JSON.stringify({ challenge: pendingAuthChallenge, demo: true }) });
    if (!result?.user && !result?.__error) {
      result = { user: { id: `local-demo-${provider}`, displayName: `Demo ${provider}` }, token: null };
    }
    if (!result?.user) {
      showToast(result?.status === 409 ? 'Ожидаем подтверждение от бота' : 'Сначала нажмите «Старт» в боте');
      return;
    }
    localStorage.setItem(authKey, JSON.stringify({ provider, loggedInAt: Date.now(), ...result }));
    $('#authPendingTitle').textContent = 'Авторизация подтверждена';
    $('#authPendingText').textContent = `Теперь послания будут приходить в ${provider === 'telegram' ? 'Telegram' : 'ВКонтакте'}.`;
    $('#authCompleteButton').hidden = true;
    showToast('Вы вошли через бота');
    setTimeout(() => {
      closeDialog($('#authDialog'));
      openDialog('dashboardDialog');
      $('#authCompleteButton').hidden = false;
    }, 600);
  });

  const dailyToggle = $('#dailyMessagesToggle');
  const retentionNote = $('#retentionNote');
  const storedDaily = localStorage.getItem(retentionKey) === 'true';
  if (dailyToggle) {
    dailyToggle.setAttribute('aria-checked', String(storedDaily));
    if (retentionNote && storedDaily) retentionNote.textContent = 'Включено: одно случайное послание в сутки после подключения бота.';
    dailyToggle.addEventListener('click', async () => {
      const enabled = dailyToggle.getAttribute('aria-checked') !== 'true';
      dailyToggle.setAttribute('aria-checked', String(enabled));
      localStorage.setItem(retentionKey, String(enabled));
      if (retentionNote) retentionNote.textContent = enabled ? 'Включено: одно случайное послание в сутки после подключения бота.' : 'По умолчанию выключено. Вы будете получать сообщения только после согласия.';
      await apiRequest('/api/v1/retention/settings', { method: 'PUT', body: JSON.stringify({ dailyEnabled: enabled }) });
      showToast(enabled ? 'Ежедневные послания включены' : 'Ежедневные послания выключены');
    });
  }

  const creatorForm = $('#creatorForm');
  creatorForm?.addEventListener('submit', async (event) => {
    event.preventDefault();
    const input = $('#creatorName');
    const normalized = input.value.trim().toLowerCase().replace(/\s+/g, '-');
    if (!normalized || normalized.length < 3) return;
    const result = await apiRequest('/api/v1/links', { method: 'POST', body: JSON.stringify({ slug: normalized }) });
    const link = result?.link || `poslaniya.app/${normalized}`;
    $('#createdLinkText').textContent = link;
    $('#createdLink').hidden = false;
    input.closest('.slug-input').style.borderColor = '#aaca9f';
    showToast('Ваша ссылка создана');
  });

  $('#copyLinkButton')?.addEventListener('click', () => copyText($('#createdLinkText').textContent));
  $('#dashboardCopyButton')?.addEventListener('click', () => copyText('https://poslaniya.app/anya'));
  $('#dashboardLinkCopy')?.addEventListener('click', () => copyText('https://poslaniya.app/anya'));

  const heroMessage = $('#heroMessage');
  const counter = $('#heroCharCount');
  heroMessage?.addEventListener('input', () => { counter.textContent = heroMessage.value.length; });
  $('#heroMessageForm')?.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (!await submitAnonymousMessage(heroMessage.value)) return;
    $('#heroMessageForm').hidden = true;
    $('#heroSuccess').hidden = false;
    heroMessage.value = '';
    counter.textContent = '0';
    setTimeout(() => {
      $('#heroMessageForm').hidden = false;
      $('#heroSuccess').hidden = true;
    }, 4500);
  });

  $('#fakePaymentButton')?.addEventListener('click', async () => {
    const button = $('#fakePaymentButton');
    button.disabled = true;
    button.innerHTML = 'Проверяем оплату…';
    await apiRequest('/api/v1/payments/checkout', { method: 'POST', body: JSON.stringify({ plan: 'vip', amount: 20, currency: 'RUB', days: 30 }) });
    setTimeout(() => {
      button.hidden = true;
      $('#paymentSuccess').hidden = false;
      showToast('VIP активирован в демо-режиме');
    }, 850);
  });

  $('#fakeRevealPaymentButton')?.addEventListener('click', async () => {
    const button = $('#fakeRevealPaymentButton');
    button.disabled = true;
    button.innerHTML = 'Проверяем…';
    await apiRequest('/api/v1/payments/checkout', { method: 'POST', body: JSON.stringify({ plan: 'reveal', amount: 7, currency: 'RUB', days: 0 }) });
    await apiRequest(`/api/v1/messages/${activeMessageId || 'demo'}/reveal`, { method: 'POST', body: JSON.stringify({ amount: 7 }) });
    setTimeout(() => {
      button.hidden = true;
      $('#revealSuccess').hidden = false;
      showToast('Запрос на раскрытие создан');
    }, 850);
  });

  $('#clearDemoButton')?.addEventListener('click', () => {
    messages = [];
    persistMessages();
    renderInbox();
    showToast('Демо-данные очищены');
  });

  $('.menu-toggle')?.addEventListener('click', () => {
    const nav = $('.desktop-nav');
    const toggle = $('.menu-toggle');
    const open = nav.classList.toggle('open');
    toggle.setAttribute('aria-expanded', String(open));
  });

  async function initializeTelegramWebApp() {
    if (!isTelegramWebApp) return;
    document.body.classList.add('telegram-webapp');
    $('#webappPanel')?.removeAttribute('hidden');
    telegramWebApp.ready();
    telegramWebApp.expand();
    const result = await apiRequest('/api/v1/auth/telegram/webapp', { method: 'POST', body: JSON.stringify({ initData: telegramWebApp.initData }) });
    if (result?.token) {
      localStorage.setItem(authKey, JSON.stringify({ provider: 'telegram', loggedInAt: Date.now(), ...result }));
      if ($('#webappUserLine') && result.user) $('#webappUserLine').textContent = `${result.user.displayName || 'Ваш ящик'} · Telegram подключён`;
    }
    await syncInbox();
  }

  $('#webappClose')?.addEventListener('click', () => {
    if (telegramWebApp) telegramWebApp.close();
    else document.body.classList.remove('telegram-webapp');
  });
  $('#webappShareButton')?.addEventListener('click', () => copyText('https://poslaniya.app/anya', 'Ссылка скопирована'));
  $('#webappRefreshButton')?.addEventListener('click', () => syncInbox().then(() => showToast('Ящик обновлён')));
  $('#webappVipButton')?.addEventListener('click', () => openDialog('paymentDialog'));
  $('#webappSettingsButton')?.addEventListener('click', () => openDialog('integrationDialog'));
  $('#webappRetentionButton')?.addEventListener('click', () => openDialog('integrationDialog'));

  // Keep the demo dashboard counters in sync after a sent message.
  renderInbox();
  renderWebAppInbox();
  initializeTelegramWebApp();
})();
