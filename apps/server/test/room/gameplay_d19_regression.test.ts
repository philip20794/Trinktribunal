import { afterEach, expect, it } from 'vitest';
import { createRoomMessage } from '../../src/protocol/room_message';
import { roomInPhase } from './game_phase_helpers';
import { cleanupPeers } from './socket_helpers';

afterEach(cleanupPeers);
for (const allJudges of [false, true])
  it(`D-19 combined online flow: replacement -> new confirmations/orders -> scored verdict -> one rule (${allJudges})`, async () => {
    const f = await roomInPhase(allJudges, 'ordering'),
      initial = await f.read();
    const old = initial.game!,
      actor = f.members.find(
        (m) => m.credential.playerId === (allJudges ? old.readerId : old.judgeId),
      )!;
    await f.send(
      actor.peer,
      createRoomMessage('rerollCurrentQuestion', {
        actionId: f.action(),
        expectedRevision: initial.revision,
        gameId: old.gameId!,
        roundId: old.round!.id,
      }),
    );
    const replaced = await f.read(),
      round = replaced.game!.round!;
    expect(round.numbers).toEqual(old.round!.numbers);
    expect(replaced.game!.completedCases).toBe(0);
    expect(replaced.game!.drawnQuestionIds).toHaveLength(2);
    await f.ordering();
    for (const member of f.members.filter(
      (m) => allJudges || m.credential.playerId === old.judgeId,
    ))
      await f.send(member.peer, await f.order([...round.recipients].reverse()));
    for (let cursor = 0; cursor < round.recipients.length; cursor++) {
      const state = await f.read();
      await f.send(
        f.host.peer,
        createRoomMessage('revealNext', {
          actionId: f.action(),
          expectedRevision: state.revision,
          gameId: old.gameId!,
          roundId: round.id,
          expectedCursor: cursor,
        }),
      );
    }
    const judged = await f.read();
    expect(judged.phase).toBe('judged');
    expect(judged.game!.round!.score?.kind).toBe(allJudges ? 'all_judges' : 'normal');
    const complete = createRoomMessage('completeCase', {
      actionId: f.action(),
      expectedRevision: judged.revision,
      gameId: old.gameId!,
      roundId: round.id,
    });
    await f.send(f.host.peer, complete);
    const done = await f.read();
    expect(done.phase).toBe('rule_event');
    expect(done.game!.completedCases).toBe(1);
    expect(done.game!.questionDraws).toHaveLength(2);
    expect(done.game!.activeRules).toHaveLength(1);
    expect(done.game!.history).toHaveLength(3);
    await f.send(f.host.peer, complete);
    expect(await f.read()).toEqual(done);
    for (const member of f.members) {
      const snapshot = await f.snapshot(member.peer);
      expect(snapshot.public.phase).toBe('rule_event');
      expect(snapshot.public.roundId).toBeNull();
      expect(snapshot.private).toEqual({});
    }
  });
