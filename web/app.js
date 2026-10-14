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
  const queryParams = new URLSearchParams(window.location.search);
  let activeMessageId = queryParams.get('messageId') || queryParams.get('replyMessageId') || null;
  const requestedPayment = queryParams.get('payment') || '';
  const requestedReply = queryParams.get('replyMessageId') || '';
  const telegramWebApp = window.Telegram?.WebApp || null;
  const appModeRequested = queryParams.get('app') === '1';
  const isTelegramWebApp = Boolean(telegramWebApp?.initData || appModeRequested);
  const queryRef = queryParams.get('ref') || '';
  let recipientSlug = queryRef.replace(/^ref[_-]/i, '').trim();
  const appConfig = {
    siteUrl: window.location.origin,
    webAppUrl: window.location.origin,
    telegramUsername: '',
    telegramUrl: '',
    vkGroupId: '',
    vkUrl: ''
  };
  let profileSlug = recipientSlug;
  const publicSiteOrigin = () => {
    try { return new URL(appConfig.siteUrl || window.location.origin).origin; } catch { return window.location.origin; }
  };
  const personalLink = (slug = profileSlug) => `${publicSiteOrigin()}/?ref=${encodeURIComponent(slug)}`;

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
      return { __error: true, status: 0 };
    }
  }

  async function loadAppConfig() {
    const result = await apiRequest('/api/v1/config');
    if (!result?.__error) Object.assign(appConfig, result);
    if (!recipientSlug) recipientSlug = appConfig.defaultRecipientSlug || '';
    return appConfig;
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

  function messageActionsMarkup(message) {
    const id = escapeHtml(message.id || '');
    const blockLabel = message.blocked ? 'Заблокирован' : 'Заблокировать';
    const replyStatus = message.replyDelivery?.status === 'unavailable'
      ? '<small class="reply-status">Ответ сохранён. Канал отправителю недоступен.</small>'
      : message.replyDelivery?.status === 'delivered'
        ? '<small class="reply-status">Ответ доставлен отправителю.</small>'
        : message.reply
          ? '<small class="reply-status">Ответ сохранён.</small>'
          : '';
    return `<div class="message-actions"><button type="button" data-reply data-message-id="${id}">Ответить</button><button type="button" data-reveal-sender data-message-id="${id}">Узнать кто · 7 ₽</button><button type="button" data-block data-message-id="${id}" ${message.blocked ? 'disabled' : ''}>${blockLabel}</button>${replyStatus}</div>`;
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
          <div class="inbox-message"><div><strong>${message.sender?.username ? `@${escapeHtml(message.sender.username)}` : message.sender?.displayName ? escapeHtml(message.sender.displayName) : 'Анонимно'}</strong><time>${escapeHtml(message.time || '')}</time></div><p>${escapeHtml(message.text)}</p>${message.reply ? `<div class="message-reply"><strong>Ваш ответ:</strong><p>${escapeHtml(message.reply.text)}</p></div>` : ''}${messageActionsMarkup(message)}<div class="message-secondary-actions"><button type="button" data-save>Сохранить</button></div></div>
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
        <div class="webapp-message-body"><div class="webapp-message-meta"><strong>${message.sender?.username ? `@${escapeHtml(message.sender.username)}` : 'Анонимно'}</strong><time>${escapeHtml(message.time || 'недавно')}</time></div><p>${escapeHtml(message.text)}</p>${message.reply ? `<div class="message-reply"><strong>Ваш ответ:</strong><p>${escapeHtml(message.reply.text)}</p></div>` : ''}${messageActionsMarkup(message)}</div>
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

  async function loadRecipient() {
    const result = await apiRequest(`/api/v1/links/${encodeURIComponent(recipientSlug)}`);
    if (!result?.displayName) return;
    const name = result.displayName;
    if ($('#recipientName')) $('#recipientName').textContent = name;
    if ($('#recipientNameLabel')) $('#recipientNameLabel').textContent = name;
    const heroRecipient = $('.recipient-row .small-label');
    if (heroRecipient) heroRecipient.textContent = 'послание для';
  }

  async function syncProfile() {
    const result = await apiRequest('/api/v1/me');
    if (result?.user) renderWebAppProfile(result.user);
    if (!result?.link?.slug) return result;
    profileSlug = result.link.slug;
    const link = personalLink();
    const shortLink = link.replace(/^https?:\/\//, '');
    ['webappPersonalLink', 'dashboardPersonalLink'].forEach((id) => { if ($(`#${id}`)) $(`#${id}`).textContent = shortLink; });
    ['webappReferralText', 'profileReferralText'].forEach((id) => { if ($(`#${id}`)) $(`#${id}`).innerHTML = `Напиши мне анонимно 💌<br />Оставь послание здесь: ${escapeHtml(shortLink)}`; });
    if ($('#webappTelegramReferral')) $('#webappTelegramReferral').href = `${appConfig.telegramUrl}?start=ref_${encodeURIComponent(profileSlug)}`;
    if ($('#webappVkReferral')) $('#webappVkReferral').href = `${appConfig.vkUrl}?ref=ref_${encodeURIComponent(profileSlug)}`;
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
    if (!recipientSlug) {
      showToast('Ссылка получателя не указана');
      return false;
    }
    const result = await apiRequest(`/api/v1/links/${encodeURIComponent(recipientSlug)}/messages`, { method: 'POST', body: JSON.stringify({ text: cleanText, channel: 'web' }) });
    if (result?.__error) {
      showToast(result.status === 404 ? 'Ссылка получателя не найдена' : result.status === 403 ? 'Отправитель заблокирован владельцем ящика' : 'Не удалось отправить. Попробуйте ещё раз');
      return false;
    }
    if (result?.message) {
      showToast('Послание отправлено');
      await syncInbox();
      return true;
    }
    showToast('Не удалось отправить. Попробуйте ещё раз');
    return false;
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
    botLink.href = isTelegram ? `${appConfig.telegramUrl}?start=auth_demo` : appConfig.vkUrl;
    botLink.innerHTML = isTelegram ? 'Открыть Telegram-бота <span>↗</span>' : 'Открыть VK-бота <span>↗</span>';
    $('.auth-options')?.setAttribute('hidden', '');
    pending.hidden = false;
    openDialog('authDialog');
    const result = await apiRequest(`/api/v1/auth/${provider}/start`, { method: 'POST', body: JSON.stringify({}) });
    pendingAuthChallenge = result?.challenge || null;
    if (result?.botUrl) botLink.href = result.botUrl;
  }

  // All buttons that open a dialog use the same small event layer.
  document.addEventListener('click', async (event) => {
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
      if (targetId === 'dashboardDialog') requestAnimationFrame(() => { syncProfile(); syncInbox(); });
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
    if (event.target.closest('.message-actions button, .message-secondary-actions button')) {
      const button = event.target.closest('button');
      const item = button.closest('.inbox-item');
      if (button.hasAttribute('data-reply')) {
        activeMessageId = button.dataset.messageId || null;
        $('#replyText').value = '';
        $('#replyDeliveryHint').textContent = 'Если канал отправителя недоступен, ответ сохранится в карточке послания без обещания доставки.';
        openDialog('replyDialog');
        return;
      }
      if (button.hasAttribute('data-block')) {
        const messageId = button.dataset.messageId || '';
        const result = await apiRequest(`/api/v1/messages/${encodeURIComponent(messageId)}/block`, { method: 'POST', body: '{}' });
        if (result?.blocked || result?.message?.blocked) {
          const local = messages.find((message) => message.id === messageId);
          if (local) local.blocked = true;
          persistMessages();
          renderInbox();
          renderWebAppInbox();
          showToast('Отправитель заблокирован');
        } else {
          showToast(result?.__error ? 'Не удалось заблокировать отправителя' : 'Для этого послания блокировка недоступна');
        }
        return;
      }
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
    await syncProfile();
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
  $('#dashboardCopyButton')?.addEventListener('click', () => copyText(personalLink()));
  $('#dashboardLinkCopy')?.addEventListener('click', () => copyText(personalLink()));

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

  $('#replyForm')?.addEventListener('submit', async (event) => {
    event.preventDefault();
    const button = $('#replySubmitButton');
    const text = $('#replyText').value.trim();
    if (!activeMessageId || !text) {
      showToast('Напишите ответ');
      return;
    }
    button.disabled = true;
    button.textContent = 'Отправляем…';
    const result = await apiRequest(`/api/v1/messages/${encodeURIComponent(activeMessageId)}/reply`, { method: 'POST', body: JSON.stringify({ text }) });
    button.disabled = false;
    button.innerHTML = 'Отправить ответ <span>↗</span>';
    if (result?.message) {
      const index = messages.findIndex((message) => message.id === activeMessageId);
      if (index >= 0) messages[index] = { ...messages[index], ...result.message };
      persistMessages();
      renderInbox();
      renderWebAppInbox();
      closeDialog($('#replyDialog'));
      showToast(result.message.replyDelivery?.status === 'unavailable' ? 'Ответ сохранён: канал отправителю недоступен' : 'Ответ отправлен');
      return;
    }
    showToast(result?.__error ? 'Не удалось отправить ответ' : 'Проверьте текст ответа');
  });

  async function startCheckout(providerButton) {
    const provider = providerButton.dataset.checkoutProvider;
    const purpose = providerButton.dataset.checkoutPurpose || 'plan';
    const plan = providerButton.dataset.checkoutPlan || null;
    const amount = purpose === 'balance' ? Number($('#topupAmount')?.value) : (plan === 'reveal' ? 7 : 20);
    if (purpose === 'balance' && (!Number.isInteger(amount) || amount < 10 || amount > 100000)) {
      showToast('Введите сумму от 10 до 100 000 ₽');
      return;
    }
    providerButton.disabled = true;
    const result = await apiRequest('/api/v1/payments/checkout', { method: 'POST', body: JSON.stringify({ provider, purpose, plan, amount, messageId: plan === 'reveal' ? activeMessageId : null }) });
    providerButton.disabled = false;
    if (result?.__error) {
      showToast(result.status === 401 ? 'Войдите через Telegram, чтобы пополнить баланс' : result.status === 402 ? 'Недостаточно средств на внутреннем балансе' : result.status === 503 ? 'Этот способ оплаты пока не настроен' : 'Не удалось создать платёж');
      return;
    }
    if (result.paymentUrl) {
      if (telegramWebApp?.openLink) telegramWebApp.openLink(result.paymentUrl);
      else window.open(result.paymentUrl, '_blank', 'noopener,noreferrer');
      showToast('Ссылка на оплату открыта');
    } else if (result.status === 'paid') {
      const success = purpose === 'balance' ? $('#topupSuccess') : plan === 'reveal' ? $('#revealSuccess') : $('#paymentSuccess');
      if (success) { success.hidden = false; success.textContent = purpose === 'balance' ? `✓ Списано с баланса. Остаток: ${result.balance} ₽` : '✓ Оплата подтверждена'; }
      await syncProfile();
      showToast('Оплата с внутреннего баланса подтверждена');
    } else if (result.instructions) {
      const success = purpose === 'balance' ? $('#topupSuccess') : plan === 'reveal' ? $('#revealSuccess') : $('#paymentSuccess');
      if (success) { success.hidden = false; success.textContent = `🏦 ${result.instructions} Чек отправьте боту для ручной проверки.`; }
      if (result.botUrl) {
        if (telegramWebApp?.openTelegramLink) telegramWebApp.openTelegramLink(result.botUrl);
        else window.open(result.botUrl, '_blank', 'noopener,noreferrer');
      }
      showToast('Заявка на СБП создана');
    }
    if (purpose === 'balance' && result.balance !== undefined && $('#webappBalance')) $('#webappBalance').textContent = `${result.balance} ₽`;
  }

  document.addEventListener('click', async (event) => {
    const checkoutButton = event.target.closest('[data-checkout-provider]');
    if (checkoutButton) {
      event.preventDefault();
      await startCheckout(checkoutButton);
      return;
    }
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

  function renderWebAppProfile(user) {
    if (!user) return;
    if ($('#webappUserLine')) $('#webappUserLine').textContent = `${user.displayName || 'Ваш ящик'}${user.username ? ` · @${user.username}` : ''}`;
    if ($('#webappBalance')) $('#webappBalance').textContent = `${Number(user.balanceRub || 0)} ₽`;
    const avatar = $('#webappAvatar');
    const fallback = $('#webappAvatarFallback');
    const photoUrl = user.photoUrl || user.photo_url;
    if (avatar && photoUrl) {
      avatar.src = photoUrl;
      avatar.hidden = false;
      if (fallback) fallback.hidden = true;
    } else if (fallback) {
      fallback.textContent = String(user.displayName || '?').trim().charAt(0).toUpperCase() || '?';
      fallback.hidden = false;
    }
  }

  async function initializeTelegramWebApp() {
    if (!isTelegramWebApp) return;
    document.body.classList.add('telegram-webapp');
    $('#webappPanel')?.removeAttribute('hidden');
    telegramWebApp?.ready?.();
    telegramWebApp?.expand?.();
    const result = telegramWebApp?.initData
      ? await apiRequest('/api/v1/auth/telegram/webapp', { method: 'POST', body: JSON.stringify({ initData: telegramWebApp.initData }) })
      : null;
    if (result?.token) {
      localStorage.setItem(authKey, JSON.stringify({ provider: 'telegram', loggedInAt: Date.now(), ...result }));
      renderWebAppProfile(result.user);
    } else if (result?.user) {
      renderWebAppProfile(result.user);
    }
    await syncProfile();
    await syncInbox();
    if (requestedPayment === 'reveal') openDialog('revealDialog');
    if (requestedPayment === 'vip') openDialog('paymentDialog');
    if (requestedPayment === 'balance') openDialog('topupDialog');
    if (requestedReply) {
      $('#replyText').value = '';
      openDialog('replyDialog');
    }
  }

  $('#webappClose')?.addEventListener('click', () => {
    if (telegramWebApp) telegramWebApp.close();
    else document.body.classList.remove('telegram-webapp');
  });
  $('#webappShareButton')?.addEventListener('click', () => copyText(personalLink(), 'Ссылка скопирована'));
  $('#webappRefreshButton')?.addEventListener('click', () => syncInbox().then(() => showToast('Ящик обновлён')));
  $('#webappVipButton')?.addEventListener('click', () => openDialog('paymentDialog'));
  $('#webappTopupButton')?.addEventListener('click', () => openDialog('topupDialog'));
  $('#webappSettingsButton')?.addEventListener('click', () => openDialog('integrationDialog'));
  $('#webappRetentionButton')?.addEventListener('click', () => openDialog('integrationDialog'));
  $('#webappDailySetting')?.addEventListener('click', () => openDialog('integrationDialog'));
  $('#webappIntegrationsSetting')?.addEventListener('click', () => openDialog('integrationDialog'));
  $('#webappSiteLink')?.addEventListener('click', () => copyText(personalLink(), 'Ссылка скопирована'));
  $$('[data-webapp-tab]').forEach((tab) => tab.addEventListener('click', () => {
    const name = tab.dataset.webappTab;
    if (name === 'vip') {
      openDialog('paymentDialog');
      return;
    }
    $$('[data-webapp-tab]').forEach((item) => item.classList.toggle('active', item === tab));
    ['inbox', 'link', 'settings'].forEach((view) => {
      const element = $(`#webapp${view[0].toUpperCase()}${view.slice(1)}View`);
      if (element) element.hidden = view !== name;
    });
  }));
  $('#profileCopyButton')?.addEventListener('click', () => copyText(personalLink(), 'Ссылка скопирована'));
  const copyReferralText = () => copyText(`Напиши мне анонимно 💌\nОставь послание здесь: ${personalLink()}`, 'Текст для профиля скопирован');
  $('#webappCopyReferral')?.addEventListener('click', copyReferralText);
  $('#profileCopyReferral')?.addEventListener('click', copyReferralText);

  // Load server configuration before resolving the referral and opening the Web App.
  (async () => {
    await loadAppConfig();
    renderInbox();
    renderWebAppInbox();
    await loadRecipient();
    await initializeTelegramWebApp();
    if (requestedPayment === 'success') showToast('Оплата передана. Ожидаем подтверждение платежа.');
  })();
})();
