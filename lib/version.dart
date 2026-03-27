const appVersion = '0.2.3';
const appCommit = String.fromEnvironment('COMMIT_SHA', defaultValue: 'dev');
const appChannel = String.fromEnvironment('CHANNEL', defaultValue: 'nightly');
