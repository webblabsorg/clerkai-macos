// Clerk Legal AI - Chrome Extension Popup Script

document.addEventListener('DOMContentLoaded', () => {
  // Check connection status
  checkConnectionStatus();
  
  // Load current selection
  loadCurrentSelection();
  
  // Setup tool item click handlers
  document.querySelectorAll('.tool-item').forEach(item => {
    item.addEventListener('click', () => {
      const action = item.dataset.action;
      executeAction(action);
    });
  });
});

async function checkConnectionStatus() {
  const statusDot = document.getElementById('statusDot');
  const statusText = document.getElementById('statusText');
  
  try {
    chrome.runtime.sendMessage({ type: 'ping' }, (response) => {
      if (chrome.runtime.lastError) {
        statusDot.classList.add('offline');
        statusText.textContent = 'Clerk app not running';
      } else {
        statusDot.classList.remove('offline');
        statusText.textContent = 'Connected to Clerk';
      }
    });
  } catch (error) {
    statusDot.classList.add('offline');
    statusText.textContent = 'Connection error';
  }
}

async function loadCurrentSelection() {
  const preview = document.getElementById('selectionPreview');
  
  // Get selection from storage
  chrome.storage.local.get(['currentSelection'], (result) => {
    if (result.currentSelection && result.currentSelection.length > 0) {
      const truncated = result.currentSelection.length > 200 
        ? result.currentSelection.substring(0, 200) + '...'
        : result.currentSelection;
      preview.textContent = truncated;
      preview.classList.remove('no-selection');
    } else {
      preview.innerHTML = '<span class="no-selection">Select text on the page to analyze</span>';
    }
  });
  
  // Also try to get current tab selection
  chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
    if (tabs[0]) {
      chrome.tabs.sendMessage(tabs[0].id, { type: 'getPageContent' }, (response) => {
        if (response && response.selectedText) {
          const truncated = response.selectedText.length > 200 
            ? response.selectedText.substring(0, 200) + '...'
            : response.selectedText;
          preview.textContent = truncated;
          preview.classList.remove('no-selection');
        }
      });
    }
  });
}

function executeAction(actionType) {
  chrome.storage.local.get(['currentSelection'], (result) => {
    const text = result.currentSelection || '';
    
    if (!text) {
      alert('Please select some text first');
      return;
    }
    
    chrome.runtime.sendMessage({
      type: 'executeAction',
      action: {
        type: actionType,
        text: text
      }
    }, (response) => {
      if (response && response.status === 'pending') {
        // Show loading state
        console.log('Action sent:', actionType);
      }
    });
  });
}

// Listen for action results
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.type === 'actionResult') {
    console.log('Action result:', request.result);
    // Update UI with result
  }
});
