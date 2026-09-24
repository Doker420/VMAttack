(() => {
  const demoKey = 'poslaniya-demo-messages';
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
          <div class="inbox-message"><div><strong>Анонимно</strong><time>${message.time}</time></div><p>${escapeHtml(message.text)}</p><div class="message-actions"><button type="button" data-reply>Ответить</button><button type="button" data-save>Сохранить</button></div></div>
          ${message.unread ? '<span class="unread-dot"></span>' : ''}
        </article>`).join('');
    }
    const count = $('#messageCount');
    const unread = $('#unreadCount');
    if (count) count.textContent = messages.length;
    if (unread) unread.textContent = messages.filter((message) => message.unread).length;
  }

  function escapeHtml(value) {
    return value.replace(/[&<>'"]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#039;', '"': '&quot;' }[char]));
  }

  function submitAnonymousMessage(text) {
    const cleanText = text.trim();
    if (cleanText.length < 3) {
      showToast('Напишите хотя бы несколько слов');
      return false;
    }
    messages.unshift({ text: cleanText, time: 'только что', mood: 'pink', unread: true });
    persistMessages();
    renderInbox();
    return true;
  }

  // All buttons that open a dialog use the same small event layer.
  document.addEventListener('click', (event) => {
    const openTrigger = event.target.closest('[data-open-dialog]');
    if (openTrigger) {
      event.preventDefault();
      const currentDialog = openTrigger.closest('dialog');
      const targetId = openTrigger.dataset.openDialog;
      if (currentDialog && currentDialog.id !== targetId) {
        closeDialog(currentDialog);
        requestAnimationFrame(() => openDialog(targetId));
      } else {
        openDialog(targetId);
      }
      $('.menu-toggle')?.setAttribute('aria-expanded', 'false');
      $('.desktop-nav')?.classList.remove('open');
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
      showToast(`${integration.dataset.integration}: подключение будет доступно после запуска бота`);
      return;
    }
    if (event.target.matches('.message-actions button')) {
      const button = event.target;
      const item = button.closest('.inbox-item');
      if (button.hasAttribute('data-reply')) showToast('Скопируйте послание и ответьте там, где удобно');
      if (button.hasAttribute('data-save')) {
        item?.classList.remove('unread');
        item?.querySelector('.unread-dot')?.remove();
        showToast('Послание сохранено');
      }
    }
  });

  // Let a click on a dialog backdrop close it, but not a click inside the card.
  $$('dialog').forEach((dialog) => dialog.addEventListener('click', (event) => {
    if (event.target === dialog) closeDialog(dialog);
  }));

  const creatorForm = $('#creatorForm');
  creatorForm?.addEventListener('submit', (event) => {
    event.preventDefault();
    const input = $('#creatorName');
    const normalized = input.value.trim().toLowerCase().replace(/\s+/g, '-');
    if (!normalized || normalized.length < 3) return;
    const link = `poslaniya.app/${normalized}`;
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
  $('#heroMessageForm')?.addEventListener('submit', (event) => {
    event.preventDefault();
    if (!submitAnonymousMessage(heroMessage.value)) return;
    $('#heroMessageForm').hidden = true;
    $('#heroSuccess').hidden = false;
    heroMessage.value = '';
    counter.textContent = '0';
    setTimeout(() => {
      $('#heroMessageForm').hidden = false;
      $('#heroSuccess').hidden = true;
    }, 4500);
  });

  $('#fakePaymentButton')?.addEventListener('click', () => {
    const button = $('#fakePaymentButton');
    button.disabled = true;
    button.innerHTML = 'Проверяем оплату…';
    setTimeout(() => {
      button.hidden = true;
      $('#paymentSuccess').hidden = false;
      showToast('Тариф подключён в демо-режиме');
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

  // Keep the demo dashboard counters in sync after a sent message.
  renderInbox();
})();
