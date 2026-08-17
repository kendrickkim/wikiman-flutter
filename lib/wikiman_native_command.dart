enum WikimanNativeCommand {
  logout,
  changeConnection,
  goHome,
  speechStart,
  speechStop,
  recordStart,
  recordStop,
  background,
  unknown,
}

WikimanNativeCommand parseWikimanNativeMessage(String message) {
  if (message.startsWith('background:')) {
    return WikimanNativeCommand.background;
  }
  switch (message) {
    case 'logout':
    case 'changeConnection':
      return WikimanNativeCommand.changeConnection;
    case 'goHome':
      return WikimanNativeCommand.goHome;
    case 'speech:start':
      return WikimanNativeCommand.speechStart;
    case 'speech:stop':
      return WikimanNativeCommand.speechStop;
    case 'record:start':
      return WikimanNativeCommand.recordStart;
    case 'record:stop':
      return WikimanNativeCommand.recordStop;
    default:
      return WikimanNativeCommand.unknown;
  }
}
