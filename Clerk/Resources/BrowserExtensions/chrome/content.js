// Clerk Legal AI - Chrome Extension Content Script

// Listen for selection changes
document.addEventListener('selectionchange', () => {
  const selection = window.getSelection();
  const selectedText = selection.toString().trim();
  
  if (selectedText.length > 0) {
    chrome.storage.local.set({ 
      currentSelection: selectedText,
      selectionUrl: window.location.href,
      selectionTimestamp: Date.now()
    });
  }
});

// Listen for messages from background script
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  switch (request.type) {
    case 'getPageContent':
      const content = {
        url: window.location.href,
        title: document.title,
        textContent: document.body.innerText,
        selectedText: window.getSelection().toString()
      };
      sendResponse(content);
      break;
      
    case 'insertText':
      insertTextAtCursor(request.text);
      sendResponse({ success: true });
      break;
      
    case 'highlightText':
      highlightTextRanges(request.ranges);
      sendResponse({ success: true });
      break;
  }
  
  return true;
});

// Insert text at current cursor position
function insertTextAtCursor(text) {
  const activeElement = document.activeElement;
  
  if (activeElement && (activeElement.tagName === 'INPUT' || activeElement.tagName === 'TEXTAREA')) {
    const start = activeElement.selectionStart;
    const end = activeElement.selectionEnd;
    const value = activeElement.value;
    
    activeElement.value = value.substring(0, start) + text + value.substring(end);
    activeElement.selectionStart = activeElement.selectionEnd = start + text.length;
    
    // Trigger input event
    activeElement.dispatchEvent(new Event('input', { bubbles: true }));
  } else if (activeElement && activeElement.isContentEditable) {
    document.execCommand('insertText', false, text);
  }
}

// Highlight text ranges (for showing analysis results)
function highlightTextRanges(ranges) {
  // Remove existing highlights
  document.querySelectorAll('.clerk-highlight').forEach(el => {
    el.outerHTML = el.innerHTML;
  });
  
  // This is a simplified implementation
  // Full implementation would use Range API for precise highlighting
  ranges.forEach(range => {
    // Implementation depends on specific use case
    console.log('Highlight range:', range);
  });
}

// Detect page type for context
function detectPageType() {
  const url = window.location.href;
  const host = window.location.hostname;
  
  // Legal research sites
  if (host.includes('westlaw.com') || host.includes('lexisnexis.com') || 
      host.includes('casetext.com') || host.includes('fastcase.com')) {
    return 'legalResearch';
  }
  
  // Court websites
  if (host.includes('.gov') || host.includes('uscourts')) {
    return 'courtWebsite';
  }
  
  // Webmail
  if (host.includes('mail.google.com') || host.includes('outlook.live.com') ||
      host.includes('outlook.office')) {
    return 'webmail';
  }
  
  // Document sites
  if (host.includes('docs.google.com') || host.includes('dropbox.com')) {
    return 'documentSite';
  }
  
  return 'general';
}

// Send page context on load
chrome.runtime.sendMessage({
  type: 'pageLoaded',
  context: {
    url: window.location.href,
    title: document.title,
    pageType: detectPageType()
  }
});
