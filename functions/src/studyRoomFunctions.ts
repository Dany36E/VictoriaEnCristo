/**
 * ═══════════════════════════════════════════════════════════════════════════
 * STUDY ROOM FUNCTIONS — Modo Estudio Colaborativo
 *
 * Salas en `studyRooms/{code}` (code 6 caracteres).
 *
 * Reglas de negocio:
 *   - Cada miembro debe usar una traducción DIFERENTE.
 *   - El host elige el libro/capítulo/rango y el intervalo de swap.
 *   - `rotateStudyVersions` rota cíclicamente las traducciones entre miembros
 *     usando `memberOrder` (host puede llamar manualmente; un scheduler hace
 *     auto-swap cada minuto si vence el intervalo).
 * ═══════════════════════════════════════════════════════════════════════════
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();

const ALLOWED_VERSIONS = ["RVR1960", "NVI", "LBLA", "NTV", "TLA"];
const MAX_MEMBERS = ALLOWED_VERSIONS.length;
const MIN_SWAP_MINUTES = 5;
const MAX_SWAP_MINUTES = 180;
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // sin O,0,1,I

const HTTPS_ERROR_CODES = new Set([
  "cancelled", "unknown", "invalid-argument", "deadline-exceeded",
  "not-found", "already-exists", "permission-denied", "resource-exhausted",
  "failed-precondition", "aborted", "out-of-range", "unimplemented",
  "internal", "unavailable", "data-loss", "unauthenticated",
]);

function rethrow(err: unknown): never {
  if (err instanceof functions.https.HttpsError) throw err;
  if (err && typeof err === "object" && "code" in err) {
    const code = (err as {code?: string}).code;
    if (typeof code === "string" && HTTPS_ERROR_CODES.has(code)) {
      const message =
        (err as {message?: string}).message ?? "Error de Firestore";
      throw new functions.https.HttpsError(
        code as functions.https.FunctionsErrorCode,
        message,
      );
    }
  }
  console.error("[study-room] internal:", err);
  throw new functions.https.HttpsError("internal", "Error interno del servidor");
}

function genCode(): string {
  let out = "";
  for (let i = 0; i < 6; i++) {
    out += CODE_ALPHABET[Math.floor(Math.random() * CODE_ALPHABET.length)];
  }
  return out;
}

interface MemberDoc {
  uid: string;
  displayName: string;
  photoUrl?: string | null;
  versionId: string;
  joinedAt: admin.firestore.Timestamp;
}

interface RoomDoc {
  code: string;
  hostUid: string;
  bookNumber: number;
  bookName: string;
  chapter: number;
  startVerse?: number | null;
  endVerse?: number | null;
  swapIntervalMinutes: number;
  createdAt: admin.firestore.Timestamp;
  lastSwapAt: admin.firestore.Timestamp;
  // Computed: lastSwapAt + swapIntervalMinutes. Indexable para que el
  // scheduler `studyRoomAutoSwap` pueda filtrar sin escanear todo.
  nextSwapAt: admin.firestore.Timestamp;
  // Cache barato del tamaño para filtrar salas huérfanas (memberCount<2).
  memberCount: number;
  memberOrder: string[];
  members: Record<string, MemberDoc>;
}

function computeNextSwapAt(
  lastSwapAt: admin.firestore.Timestamp,
  swapIntervalMinutes: number,
): admin.firestore.Timestamp {
  return admin.firestore.Timestamp.fromMillis(
    lastSwapAt.toMillis() + swapIntervalMinutes * 60 * 1000,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// CREATE ROOM
// ═══════════════════════════════════════════════════════════════════════════

export const createStudyRoom = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated", "Inicia sesión para crear una sala.");
    }
    const uid = context.auth.uid;

    const bookNumber = Number(data?.bookNumber);
    const bookName = String(data?.bookName ?? "").trim();
    const chapter = Number(data?.chapter);
    const versionId = String(data?.versionId ?? "RVR1960");
    const swapMin = Number(data?.swapIntervalMinutes ?? 15);
    const startVerse = data?.startVerse !== undefined && data?.startVerse !== null
      ? Number(data.startVerse) : null;
    const endVerse = data?.endVerse !== undefined && data?.endVerse !== null
      ? Number(data.endVerse) : null;
    const displayName = String(data?.displayName ?? "Hermano(a)").trim();
    const photoUrl: string | null =
      typeof data?.photoUrl === "string" ? data.photoUrl : null;

    if (!Number.isFinite(bookNumber) || bookNumber < 1 || bookNumber > 66) {
      throw new functions.https.HttpsError(
        "invalid-argument", "Libro inválido.");
    }
    if (!bookName) {
      throw new functions.https.HttpsError(
        "invalid-argument", "Nombre de libro requerido.");
    }
    if (!Number.isFinite(chapter) || chapter < 1) {
      throw new functions.https.HttpsError(
        "invalid-argument", "Capítulo inválido.");
    }
    if (!ALLOWED_VERSIONS.includes(versionId)) {
      throw new functions.https.HttpsError(
        "invalid-argument", "Versión bíblica no soportada.");
    }
    if (!Number.isFinite(swapMin) ||
        swapMin < MIN_SWAP_MINUTES || swapMin > MAX_SWAP_MINUTES) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Intervalo de swap debe estar entre ${MIN_SWAP_MINUTES} y ${MAX_SWAP_MINUTES} minutos.`);
    }

    // Buscar un código único (3 intentos)
    const now = admin.firestore.Timestamp.now();
    for (let attempt = 0; attempt < 5; attempt++) {
      const code = genCode();
      const ref = db.collection("studyRooms").doc(code);
      const snap = await ref.get();
      if (snap.exists) continue;

      const member: MemberDoc = {
        uid,
        displayName: displayName || "Hermano(a)",
        photoUrl: photoUrl,
        versionId,
        joinedAt: now,
      };
      const room: RoomDoc = {
        code,
        hostUid: uid,
        bookNumber,
        bookName,
        chapter,
        startVerse: startVerse,
        endVerse: endVerse,
        swapIntervalMinutes: swapMin,
        createdAt: now,
        lastSwapAt: now,
        nextSwapAt: computeNextSwapAt(now, swapMin),
        memberCount: 1,
        memberOrder: [uid],
        members: {[uid]: member},
      };
      await ref.set(room);
      return {code, room: serializeRoom(room)};
    }

    throw new functions.https.HttpsError(
      "resource-exhausted",
      "No se pudo generar un código único, intenta de nuevo.");
  } catch (err) {
    rethrow(err);
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// JOIN ROOM
// ═══════════════════════════════════════════════════════════════════════════

export const joinStudyRoom = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated", "Inicia sesión para unirte a una sala.");
    }
    const uid = context.auth.uid;
    const code = String(data?.code ?? "").trim().toUpperCase();
    const versionId = String(data?.versionId ?? "RVR1960");
    const displayName = String(data?.displayName ?? "Hermano(a)").trim();
    const photoUrl: string | null =
      typeof data?.photoUrl === "string" ? data.photoUrl : null;

    if (code.length !== 6) {
      throw new functions.https.HttpsError(
        "invalid-argument", "El código debe tener 6 caracteres.");
    }
    if (!ALLOWED_VERSIONS.includes(versionId)) {
      throw new functions.https.HttpsError(
        "invalid-argument", "Versión bíblica no soportada.");
    }

    const ref = db.collection("studyRooms").doc(code);
    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new functions.https.HttpsError(
          "not-found", "No encontramos esa sala. Verifica el código.");
      }
      const room = snap.data() as RoomDoc;
      const members = room.members ?? {};
      if (members[uid]) {
        // Idempotente: ya estaba dentro.
        return room;
      }
      if (Object.keys(members).length >= MAX_MEMBERS) {
        throw new functions.https.HttpsError(
          "resource-exhausted",
          "La sala está llena (máximo " + MAX_MEMBERS + " miembros).");
      }
      // Versión debe ser distinta a las existentes.
      const taken = new Set<string>();
      Object.values(members).forEach((m) => taken.add(m.versionId));
      if (taken.has(versionId)) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Esa versión ya está tomada. Elige una traducción diferente.");
      }
      const newMember: MemberDoc = {
        uid,
        displayName: displayName || "Hermano(a)",
        photoUrl,
        versionId,
        joinedAt: admin.firestore.Timestamp.now(),
      };
      const memberOrder = [...(room.memberOrder ?? []), uid];
      tx.update(ref, {
        [`members.${uid}`]: newMember,
        memberOrder,
        memberCount: memberOrder.length,
      });
      return {
        ...room,
        members: {...members, [uid]: newMember},
        memberOrder,
        memberCount: memberOrder.length,
      };
    });
    return {room: serializeRoom(result)};
  } catch (err) {
    rethrow(err);
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// LEAVE ROOM
// ═══════════════════════════════════════════════════════════════════════════

export const leaveStudyRoom = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated", "Inicia sesión.");
    }
    const uid = context.auth.uid;
    const code = String(data?.code ?? "").trim().toUpperCase();
    if (code.length !== 6) {
      throw new functions.https.HttpsError(
        "invalid-argument", "Código inválido.");
    }
    const ref = db.collection("studyRooms").doc(code);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return;
      const room = snap.data() as RoomDoc;
      const members = {...(room.members ?? {})};
      if (!members[uid]) return;
      delete members[uid];
      const memberOrder = (room.memberOrder ?? []).filter((u) => u !== uid);
      // Si era el host, transferir; si queda vacía, borrar.
      if (Object.keys(members).length === 0) {
        tx.delete(ref);
        return;
      }
      const newHost = room.hostUid === uid ? memberOrder[0] : room.hostUid;
      tx.update(ref, {
        [`members.${uid}`]: admin.firestore.FieldValue.delete(),
        memberOrder,
        memberCount: memberOrder.length,
        hostUid: newHost,
      });
    });
    return {ok: true};
  } catch (err) {
    rethrow(err);
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// ROTATE VERSIONS  (manual o auto via scheduler)
// ═══════════════════════════════════════════════════════════════════════════

async function rotateRoomVersions(code: string, force: boolean): Promise<RoomDoc | null> {
  const ref = db.collection("studyRooms").doc(code);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return null;
    const room = snap.data() as RoomDoc;
    const memberOrder = room.memberOrder ?? [];
    if (memberOrder.length < 2) return room;

    if (!force) {
      const last = (room.lastSwapAt as admin.firestore.Timestamp).toMillis();
      const next = last + room.swapIntervalMinutes * 60 * 1000;
      if (Date.now() < next) return room; // todavía no toca
    }

    // Rotar versionId entre miembros siguiendo memberOrder.
    // member[i] recibe la versión que tenía member[i-1] (cíclico).
    const versions = memberOrder.map(
      (u) => (room.members[u]?.versionId ?? "RVR1960"));
    const rotated = [versions[versions.length - 1], ...versions.slice(0, -1)];
    const nowTs = admin.firestore.Timestamp.now();
    const updates: Record<string, unknown> = {
      lastSwapAt: nowTs,
      nextSwapAt: computeNextSwapAt(nowTs, room.swapIntervalMinutes ?? 15),
    };
    memberOrder.forEach((u, i) => {
      updates[`members.${u}.versionId`] = rotated[i];
    });
    tx.update(ref, updates);
    return {...room, members: Object.fromEntries(memberOrder.map(
      (u, i) => [u, {...room.members[u], versionId: rotated[i]}]))} as RoomDoc;
  });
}

export const rotateStudyVersions = functions.https.onCall(
  async (data, context) => {
    try {
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated", "Inicia sesión.");
      }
      const code = String(data?.code ?? "").trim().toUpperCase();
      const force = Boolean(data?.force ?? true);
      if (code.length !== 6) {
        throw new functions.https.HttpsError(
          "invalid-argument", "Código inválido.");
      }
      // Verificar que el caller esté en la sala.
      const ref = db.collection("studyRooms").doc(code);
      const snap = await ref.get();
      if (!snap.exists) {
        throw new functions.https.HttpsError(
          "not-found", "Sala no encontrada.");
      }
      const room = snap.data() as RoomDoc;
      if (!room.members?.[context.auth.uid]) {
        throw new functions.https.HttpsError(
          "permission-denied", "No eres miembro de esta sala.");
      }
      const updated = await rotateRoomVersions(code, force);
      return {room: updated ? serializeRoom(updated) : null};
    } catch (err) {
      rethrow(err);
    }
  });

// Scheduler: cada 5 minutos rota las salas cuyo `nextSwapAt` ya venció.
// Filtra el query con `where(nextSwapAt <= now)` y `where(memberCount >= 2)`
// para no escanear toda la colección. Además, limpia salas huérfanas
// (sin actividad por más de 24h) para evitar acumulación de basura.
export const studyRoomAutoSwap = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    // 1. Salas que necesitan rotar.
    const dueSnap = await db.collection("studyRooms")
      .where("memberCount", ">=", 2)
      .where("nextSwapAt", "<=", now)
      .limit(50)
      .get();
    const tasks: Promise<unknown>[] = [];
    for (const doc of dueSnap.docs) {
      tasks.push(rotateRoomVersions(doc.id, true).catch((e) => {
        console.warn(`[study-room] auto-swap failed for ${doc.id}:`, e);
      }));
    }
    // 2. Limpieza de salas inactivas > 24h (best-effort, límite chico).
    const cutoff = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - 24 * 60 * 60 * 1000,
    );
    const staleSnap = await db.collection("studyRooms")
      .where("lastSwapAt", "<", cutoff)
      .limit(20)
      .get();
    for (const doc of staleSnap.docs) {
      tasks.push(doc.ref.delete().catch((e) => {
        console.warn(`[study-room] delete stale ${doc.id} failed:`, e);
      }));
    }
    await Promise.all(tasks);
    return null;
  });

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════

function serializeRoom(room: RoomDoc): Record<string, unknown> {
  // Convierte Timestamps a millisecond numbers para que el cliente Dart no
  // tenga que depender de Timestamp (callable serializa con JSON plano).
  const ts = (t: admin.firestore.Timestamp | undefined) =>
    t ? {seconds: t.seconds, nanoseconds: t.nanoseconds} : null;
  return {
    code: room.code,
    hostUid: room.hostUid,
    bookNumber: room.bookNumber,
    bookName: room.bookName,
    chapter: room.chapter,
    startVerse: room.startVerse ?? null,
    endVerse: room.endVerse ?? null,
    swapIntervalMinutes: room.swapIntervalMinutes,
    createdAt: ts(room.createdAt),
    lastSwapAt: ts(room.lastSwapAt),
    memberOrder: room.memberOrder ?? [],
    members: room.members ?? {},
  };
}
