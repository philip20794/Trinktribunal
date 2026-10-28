import { expect } from 'vitest';
import { createRoomMessage } from '../../src/protocol/room_message';
import { requestId } from './socket_helpers';
import { allJudgesRoom } from './all_judges_helpers';

/** Real committed transitions, shared by persistence and membership unit suites. */
export async function roomInPhase(allJudges: boolean, phase: string) {
  const f = await allJudgesRoom(3, allJudges, phase !== 'lobby');
  async function complete() {
    const state = await f.read();
    await f.send(
      f.host.peer,
      createRoomMessage('completeWithoutVerdict', {
        actionId: f.action(),
        expectedRevision: state.revision,
        gameId: state.game!.gameId!,
        roundId: state.game!.round!.id,
        confirmed: true,
      }),
    );
  }
  async function rule() {
    const state = await f.read();
    await f.send(
      f.host.peer,
      createRoomMessage('continueRule', {
        actionId: f.action(),
        expectedRevision: state.revision,
        gameId: state.game!.gameId!,
        afterCase: state.game!.completedCases,
      }),
    );
  }
  if (phase === 'rule_event' || phase === 'finished') {
    do {
      await complete();
      if ((await f.read()).phase === 'rule_event' && phase === 'finished') await rule();
    } while (phase === 'finished' && (await f.read()).phase !== 'finished');
  } else if (phase === 'paused') {
    const result = await f.room.stub.leave(
      createRoomMessage('leaveHttp', {
        requestId: requestId(),
        actionId: f.action(),
        resumeToken: f.members[1]!.credential.resumeToken,
        confirmed: true,
      }),
    );
    expect(result.ok).toBe(true);
    await complete();
  } else if (!['lobby', 'numbers'].includes(phase)) {
    const recipients = f.initial.round!.recipients;
    for (const member of f.members.filter((m) => recipients.includes(m.credential.playerId)))
      await f.send(member.peer, await f.command('acknowledgeNumber'));
    if (phase !== 'answers') {
      for (const member of f.members)
        await f.send(member.peer, await f.command('readyForOrdering'));
      await f.send(f.host.peer, await f.command('beginOrdering'));
      if (phase !== 'ordering') {
        for (const member of f.members.filter(
          (m) => allJudges || m.credential.playerId === f.initial.judgeId,
        ))
          await f.send(member.peer, await f.order(recipients));
        if (phase === 'judged')
          for (let cursor = 0; cursor < recipients.length; cursor++) {
            const state = await f.read();
            await f.send(
              f.host.peer,
              createRoomMessage('revealNext', {
                actionId: f.action(),
                expectedRevision: state.revision,
                gameId: state.game!.gameId!,
                roundId: state.game!.round!.id,
                expectedCursor: cursor,
              }),
            );
          }
      }
    }
  }
  expect((await f.read()).phase).toBe(phase);
  return f;
}
