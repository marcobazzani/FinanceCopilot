const appVersion = '0.1.48';
const appCommit = String.fromEnvironment('COMMIT_SHA', defaultValue: 'dev');
const appChannel = String.fromEnvironment('CHANNEL', defaultValue: 'nightly');
