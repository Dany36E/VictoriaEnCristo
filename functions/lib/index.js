"use strict";
/**
 * ═══════════════════════════════════════════════════════════════════════════
 * CLOUD FUNCTIONS - Victoria en Cristo
 * Funciones administrativas que requieren privilegios de admin
 * ═══════════════════════════════════════════════════════════════════════════
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.purgeOldPartnerInvites = exports.onBattleMessageCreated = exports.onPartnerInviteCreated = exports.banAbuseHash = exports.reportContent = exports.moderateContent = exports.createWallComment = exports.createWallPost = exports.deleteUserData = void 0;
const admin = require("firebase-admin");
// Inicializar Firebase Admin ANTES de importar otras funciones
admin.initializeApp();
// Exportar funciones
var deleteUserData_1 = require("./deleteUserData");
Object.defineProperty(exports, "deleteUserData", { enumerable: true, get: function () { return deleteUserData_1.deleteUserData; } });
// Muro de Batalla - Funciones de moderación anónima
var wallFunctions_1 = require("./wallFunctions");
Object.defineProperty(exports, "createWallPost", { enumerable: true, get: function () { return wallFunctions_1.createWallPost; } });
Object.defineProperty(exports, "createWallComment", { enumerable: true, get: function () { return wallFunctions_1.createWallComment; } });
Object.defineProperty(exports, "moderateContent", { enumerable: true, get: function () { return wallFunctions_1.moderateContent; } });
Object.defineProperty(exports, "reportContent", { enumerable: true, get: function () { return wallFunctions_1.reportContent; } });
Object.defineProperty(exports, "banAbuseHash", { enumerable: true, get: function () { return wallFunctions_1.banAbuseHash; } });
// Compañero de Batalla - Push notifications y purga
var battlePartnerFunctions_1 = require("./battlePartnerFunctions");
Object.defineProperty(exports, "onPartnerInviteCreated", { enumerable: true, get: function () { return battlePartnerFunctions_1.onPartnerInviteCreated; } });
Object.defineProperty(exports, "onBattleMessageCreated", { enumerable: true, get: function () { return battlePartnerFunctions_1.onBattleMessageCreated; } });
Object.defineProperty(exports, "purgeOldPartnerInvites", { enumerable: true, get: function () { return battlePartnerFunctions_1.purgeOldPartnerInvites; } });
//# sourceMappingURL=index.js.map