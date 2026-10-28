// Runs in Vitest's host process; Worker console buffering cannot lose the report.
export default class LocalLoadReporter {
  onTestCaseAnnotate(_test, annotation) {
    if(annotation.message.startsWith('TT_LOCAL_METRICS ')) process.stdout.write(annotation.message+'\n');
  }
}
