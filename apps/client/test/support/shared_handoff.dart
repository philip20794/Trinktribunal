import 'package:trinktribunal/application/shared_phone_controller.dart';
import 'package:trinktribunal/domain/models/game_mode.dart';

SharedGameView openSharedRecipient(SharedPhoneController session) {
  var view = session.view!;
  if (view.numberStage == SharedNumberStage.caseFile) {
    session.beginNumberHandoff(view.roundId);
    view = session.view!;
  }
  if (view.numberStage == SharedNumberStage.recipientHandoff) {
    session.confirmRecipient(roundId: view.roundId, player: view.recipient!);
  }
  return session.view!;
}

void finishSharedNumbers(SharedPhoneController session) {
  while (session.view!.phase == GamePhase.numbers) {
    var view = session.view!;
    if (view.numberStage == SharedNumberStage.judgeHandoff) {
      session.confirmJudge(roundId: view.roundId, judge: view.judge!);
    } else {
      view = openSharedRecipient(session);
      session.revealOwnNumber(roundId: view.roundId, player: view.recipient!);
      session.acknowledgeNumber(roundId: view.roundId, player: view.recipient!);
    }
  }
}
