javascript:(function () {
  /*
   * PURPOSE
   * Copy the current page as two clipboard formats in one operation:
   *   - text/html: a clickable link for Word, Outlook, Slack, and rich editors.
   *   - text/plain: a CommonMark link, [Page title](<https://example.com/>).
   * The receiving application chooses the format it supports.
   *
   * INSTALLATION
   * Create a browser bookmark and paste this entire file into its URL/location.
   * Invoke the bookmark while viewing the page whose title and URL you want.
   *
   * WHEN TO USE IT
   * Use it when you want a labeled link rather than a bare URL. It reads only
   * document.title and window.location.href, performs no network requests, and
   * does not modify the page except for a temporary hidden textarea in fallback
   * mode.
   *
   * WHEN NOT TO USE IT
   * Review the address bar first. The complete URL is copied, including query
   * parameters and fragments, which can contain account-recovery codes, signed
   * download tokens, internal hostnames, or other sensitive information. Browser
   * internal pages and pages that block JavaScript URLs may reject bookmarklets.
   *
   * COMPATIBILITY
   * Modern browsers use navigator.clipboard.write() with text/html and text/plain.
   * That API requires a secure context and user activation. An execCommand('copy')
   * fallback remains for older/insecure pages even though that API is deprecated.
   * If both methods fail, a prompt exposes the Markdown text for manual copying.
   */

  'use strict';

  var url = window.location.href;
  var title = String(document.title || '').replace(/\s+/g, ' ').trim();

  if (!title) {
    title = window.location.hostname || url;
  }

  function escapeMarkdownText(value) {
    // Preserve literal title text across CommonMark and common extensions.
    return value.replace(/([\\[\]`*_{}<>|~^&])/g, '\\$1');
  }

  function escapeMarkdownDestination(value) {
    return value
      .replace(/\\/g, '%5C')
      .replace(/</g, '%3C')
      .replace(/>/g, '%3E')
      .replace(/[\r\n]/g, '');
  }

  var markdown = '[' + escapeMarkdownText(title) + '](<' +
    escapeMarkdownDestination(url) + '>)';

  var anchor = document.createElement('a');
  anchor.setAttribute('href', url);
  anchor.textContent = title;
  var html = anchor.outerHTML;

  function copyWithExecCommand() {
    var host = document.body || document.documentElement;
    if (!host || typeof document.execCommand !== 'function') {
      return false;
    }

    var activeElement = document.activeElement;
    var inputSelection = null;
    if (activeElement && typeof activeElement.selectionStart === 'number') {
      inputSelection = {
        start: activeElement.selectionStart,
        end: activeElement.selectionEnd,
        direction: activeElement.selectionDirection
      };
    }

    var selection = typeof window.getSelection === 'function' ? window.getSelection() : null;
    var savedRanges = [];
    if (selection) {
      for (var index = 0; index < selection.rangeCount; index += 1) {
        savedRanges.push(selection.getRangeAt(index).cloneRange());
      }
    }

    var textarea = document.createElement('textarea');
    textarea.value = markdown;
    textarea.setAttribute('readonly', '');
    textarea.style.position = 'fixed';
    textarea.style.left = '-9999px';
    textarea.style.top = '0';
    textarea.style.opacity = '0';
    textarea.style.pointerEvents = 'none';

    function onCopy(event) {
      if (!event.clipboardData) { return; }
      event.clipboardData.setData('text/plain', markdown);
      event.clipboardData.setData('text/html', html);
      event.preventDefault();
      event.stopImmediatePropagation();
    }

    document.addEventListener('copy', onCopy, true);
    try {
      host.appendChild(textarea);
      textarea.focus();
      textarea.select();
      textarea.setSelectionRange(0, textarea.value.length);
      return document.execCommand('copy') === true;
    } finally {
      document.removeEventListener('copy', onCopy, true);
      if (textarea.parentNode) {
        textarea.parentNode.removeChild(textarea);
      }

      if (activeElement && typeof activeElement.focus === 'function') {
        try {
          activeElement.focus({ preventScroll: true });
        } catch (ignore) {
          activeElement.focus();
        }
      }

      if (inputSelection && typeof activeElement.setSelectionRange === 'function') {
        activeElement.setSelectionRange(
          inputSelection.start,
          inputSelection.end,
          inputSelection.direction
        );
      }

      if (selection) {
        selection.removeAllRanges();
        savedRanges.forEach(function (range) {
          selection.addRange(range);
        });
      }
    }
  }

  function manualFallback(error) {
    if (error && window.console && typeof window.console.warn === 'function') {
      window.console.warn('Modern clipboard copy failed; trying legacy fallback.', error);
    }

    try {
      if (copyWithExecCommand()) { return; }
    } catch (fallbackError) {
      if (window.console && typeof window.console.warn === 'function') {
        window.console.warn('Legacy clipboard copy failed.', fallbackError);
      }
    }

    window.prompt('Automatic copy was blocked. Copy this Markdown link:', markdown);
  }

  var clipboard = window.navigator && window.navigator.clipboard;
  var canWriteRichClipboard = window.isSecureContext &&
    clipboard &&
    typeof clipboard.write === 'function' &&
    typeof window.ClipboardItem === 'function' &&
    typeof window.Blob === 'function';

  if (!canWriteRichClipboard) {
    manualFallback();
    return;
  }

  try {
    var item = new window.ClipboardItem({
      'text/plain': new window.Blob([markdown], { type: 'text/plain' }),
      'text/html': new window.Blob([html], { type: 'text/html' })
    });
    var writeResult = clipboard.write([item]);
    if (writeResult && typeof writeResult.then === 'function') {
      writeResult.then(null, manualFallback);
    }
  } catch (error) {
    manualFallback(error);
  }
})();
