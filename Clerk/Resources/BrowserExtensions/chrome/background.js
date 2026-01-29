// Clerk Legal AI - Chrome Extension Background Service Worker

const NATIVE_HOST_NAME = 'com.clerk.legal.native';

// Native messaging port
let nativePort = null;

// Connect to native messaging host
function connectToNativeHost() {
  if (nativePort) return nativePort;
  
  try {
    nativePort = chrome.runtime.connectNative(NATIVE_HOST_NAME);
    
    nativePort.onMessage.addListener((message) => {
      console.log('Received from native host:', message);
      handleNativeMessage(message);
    });
    
    nativePort.onDisconnect.addListener(() => {
      console.log('Disconnected from native host');
      nativePort = null;
    });
    
    return nativePort;
  } catch (error) {
    console.error('Failed to connect to native host:', error);
    return null;
  }
}

// Send message to native host
function sendToNativeHost(message) {
  const port = connectToNativeHost();
  if (port) {
    port.postMessage(message);
  } else {
    console.error('Native host not connected');
  }
}

// Handle messages from native host
function handleNativeMessage(message) {
  if (message.success && message.data) {
    switch (message.data.type) {
      case 'context':
        chrome.storage.local.set({ currentContext: message.data.context });
        break;
      case 'actionResult':
        // Notify popup or content script
        chrome.runtime.sendMessage({ type: 'actionResult', result: message.data.actionResult });
        break;
    }
  }
}

// Context menu setup
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: 'clerk-analyze',
    title: 'Analyze with Clerk',
    contexts: ['selection']
  });
  
  chrome.contextMenus.create({
    id: 'clerk-summarize',
    title: 'Summarize with Clerk',
    contexts: ['selection']
  });
  
  chrome.contextMenus.create({
    id: 'clerk-draft-response',
    title: 'Draft Response',
    contexts: ['selection']
  });
});

// Context menu click handler
chrome.contextMenus.onClicked.addListener((info, tab) => {
  const selectedText = info.selectionText;
  
  switch (info.menuItemId) {
    case 'clerk-analyze':
      sendToNativeHost({
        type: 'executeAction',
        action: { type: 'analyze', text: selectedText }
      });
      break;
    case 'clerk-summarize':
      sendToNativeHost({
        type: 'executeAction',
        action: { type: 'summarize', text: selectedText }
      });
      break;
    case 'clerk-draft-response':
      sendToNativeHost({
        type: 'executeAction',
        action: { type: 'draftResponse', text: selectedText }
      });
      break;
  }
});

// Message handler from popup and content scripts
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  switch (request.type) {
    case 'getContext':
      sendToNativeHost({ type: 'getContext' });
      sendResponse({ status: 'pending' });
      break;
      
    case 'getSelection':
      sendToNativeHost({ type: 'getSelection' });
      sendResponse({ status: 'pending' });
      break;
      
    case 'executeAction':
      sendToNativeHost({
        type: 'executeAction',
        action: request.action
      });
      sendResponse({ status: 'pending' });
      break;
      
    case 'ping':
      sendToNativeHost({ type: 'ping' });
      sendResponse({ status: 'pending' });
      break;
  }
  
  return true; // Keep channel open for async response
});

// Keyboard shortcut handler
chrome.commands.onCommand.addListener((command) => {
  if (command === 'open-clerk') {
    chrome.action.openPopup();
  }
});
