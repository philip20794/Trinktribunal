import type {
  EditOwnProfileMessage,
  KickMessage,
  ReorderRosterMessage,
  PlayerId,
  Profile,
} from '../protocol/room_message.generated';
import { protocolMetadata } from '../protocol/room_message.generated';
import { canonicalJson } from '../../../../packages/protocol/schema-validation.mjs';

export interface LobbyReceipt {
  actionId: string;
  playerId: PlayerId;
  fingerprint: string;
  revision: number;
}
interface LobbyState {
  hostId: PlayerId;
  phase: string;
  revision: number;
  lastDomainActivity: number;
  members: Array<{ playerId: PlayerId; profile?: Profile; revoked: boolean }>;
  lobbyReceipts?: LobbyReceipt[];
}
type LobbyAction = EditOwnProfileMessage | KickMessage | ReorderRosterMessage;
export async function lobbyFingerprint(command: LobbyAction): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(canonicalJson(command)),
  );
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
}
export function applyLobbyAction(
  state: LobbyState,
  playerId: PlayerId,
  command: LobbyAction,
  fingerprint: string,
  now: number,
):
  | { ok: true; revision: number; duplicate: boolean; removedPlayerId?: PlayerId }
  | {
      ok: false;
      code:
        | 'CREDENTIAL_INVALID'
        | 'STALE_REVISION'
        | 'ACTION_ID_CONFLICT'
        | 'RATE_LIMITED'
        | 'UNAUTHORIZED_ACTION'
        | 'INVALID_PHASE'
        | 'INVALID_PERMUTATION'
        | 'INVALID_MESSAGE';
    } {
  const member = state.members.find((member) => member.playerId === playerId && !member.revoked);
  if (!member) return { ok: false, code: 'CREDENTIAL_INVALID' };
  const previous = state.lobbyReceipts?.find((receipt) => receipt.actionId === command.actionId);
  if (previous)
    return previous.playerId === playerId && previous.fingerprint === fingerprint
      ? { ok: true, revision: previous.revision, duplicate: true }
      : { ok: false, code: 'ACTION_ID_CONFLICT' };
  if (command.expectedRevision !== state.revision) return { ok: false, code: 'STALE_REVISION' };
  if ((state.lobbyReceipts?.length ?? 0) >= protocolMetadata.limits.actionJournalEntries)
    return { ok: false, code: 'RATE_LIMITED' };
  let removedPlayerId: PlayerId | undefined;
  if (command.type === 'editOwnProfile') member.profile = command.profile;
  else {
    if (playerId !== state.hostId) return { ok: false, code: 'UNAUTHORIZED_ACTION' };
    if (command.type === 'kick') {
      const target = state.members.find(
        (member) => member.playerId === command.targetPlayerId && !member.revoked,
      );
      if (!target || target.playerId === state.hostId)
        return { ok: false, code: 'INVALID_MESSAGE' };
      target.revoked = true;
      removedPlayerId = target.playerId;
    } else {
      const active = state.members.filter((member) => !member.revoked);
      if (
        command.playerIds.length !== active.length ||
        new Set(command.playerIds).size !== active.length ||
        command.playerIds.some((id) => !active.some((member) => member.playerId === id))
      )
        return { ok: false, code: 'INVALID_PERMUTATION' };
      state.members = [
        ...command.playerIds.map((id) => active.find((member) => member.playerId === id)!),
        ...state.members.filter((member) => member.revoked),
      ];
    }
  }
  state.revision++;
  state.lastDomainActivity = now;
  (state.lobbyReceipts ??= []).push({
    actionId: command.actionId,
    playerId,
    fingerprint,
    revision: state.revision,
  });
  return {
    ok: true,
    revision: state.revision,
    duplicate: false,
    ...(removedPlayerId ? { removedPlayerId } : {}),
  };
}
