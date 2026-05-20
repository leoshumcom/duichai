/**
 * 堆柴 API - Cloudflare Workers
 * 众人拾柴火焰高
 */

import { Router } from './router';
import { jsonResponse, corsHeaders } from './utils';
import { initDB } from './db/init';
import { handleRegister, handleLogin, handleLoginByUid, handleGetUser, handleGetMe, handleGetMyUid, handleSetUserUid } from './routes/auth';
import { handlePublicStats, handleDownloadApk } from './routes/public';
import { handleCreateVenue, handleGetVenue, handleSearchVenues, handleTipVenue, handleSupplementVenue, handleUpdateVenue, handleGetVenueReviews, handleCreateMatch, handleGetVenueMatches, handleJoinMatch, handleOwnerApply } from './routes/venues';
import { handleUpload, handleBatchUpload, handleDeleteFile } from './routes/upload';
import { handleCreateClub, handleListClubs, handleGetClub, handleUpdateClub, handleClubCertification, handleJoinClub, handleJoinRequest, handleListJoinRequests, handleApproveJoinRequest, handleRejectJoinRequest } from './routes/clubs';
import { handleSendClubMessage, handleGetClubMessages } from './routes/club_messages';
import { handleDashboardStats, handleUserTrend, handleRankings, handleAdminLogin, handleGrantChaihuo, handleAdminUsers, handleAdminVenues, handleAdminApproveVenue, handleAdminDeleteVenue, handleAdminOwnerApplications, handleAdminApproveOwnerApplication, handleAdminRejectOwnerApplication, handleAdminClubs, handleAdminClubCertifications, handleAdminApproveClubCert, handleAdminRejectClubCert, handleLevelInfo } from './routes/admin';
import { handleMyTips, handleMyBadges, handleMyClubs, handleMyVenues, handleMyInvites, handleNotifications, handleMarkRead, handleUpdateAvatar, handleUpdateProfile, handleLevelInfo } from './routes/profile';
import { handleDetectFace, handleFaceAuth } from './routes/face_auth';

interface Env {
  duichai_db: D1Database;
  duichai_assets?: R2Bucket;
  APP_NAME: string;
  ENV: string;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const router = new Router();

    // CORS
    router.add('OPTIONS', '/*', (req) => {
      return new Response(null, { headers: corsHeaders(req) });
    });

    // Public stats (no auth required)
    router.add('GET', '/api/public/stats', async (req) => handlePublicStats(req, env));
    router.add('GET', '/api/download/android', async (req) => handleDownloadApk(req, env));

    // Health check
    router.add('GET', '/api/health', async () => {
      return jsonResponse({
        app: env.APP_NAME,
        status: 'ok',
        env: env.ENV,
        timestamp: new Date().toISOString(),
      });
    });

    // DB init (dev only)
    router.add('POST', '/api/db/init', async () => {
      if (env.ENV !== 'development') {
        return jsonResponse({ error: 'Not allowed in production' }, 403);
      }
      await initDB(env.duichai_db);
      return jsonResponse({ success: true, message: 'Database initialized' });
    });

    // ===== Auth =====
    router.add('POST', '/api/auth/register', async (req) => handleRegister(req, env));
    router.add('POST', '/api/auth/login', async (req) => handleLogin(req, env));
    router.add('POST', '/api/auth/login-by-uid', async (req) => handleLoginByUid(req, env));
    router.add('GET', '/api/users/me', async (req) => handleGetMe(req, env));
    router.add('GET', '/api/users/me/uid', async (req) => handleGetMyUid(req, env));
    router.add('GET', '/api/users/:id', async (req, params) => handleGetUser(req, env, params.id));
    router.add('POST', '/api/admin/users/set-uid', async (req) => handleSetUserUid(req, env));

    // ===== Venues =====
    router.add('POST', '/api/venues', async (req) => handleCreateVenue(req, env));
    router.add('GET', '/api/venues/:id', async (req, params) => handleGetVenue(req, env, params.id));
    router.add('GET', '/api/venues/:id/reviews', async (req, params) => handleGetVenueReviews(req, env, params.id));
    router.add('GET', '/api/venues', async (req) => handleSearchVenues(req, env));
    router.add('POST', '/api/venues/tip', async (req) => handleTipVenue(req, env));
    router.add('POST', '/api/venues/supplement', async (req) => handleSupplementVenue(req, env));
    router.add('POST', '/api/venues/:id/update', async (req, params) => handleUpdateVenue(req, env, params.id));
    router.add('POST', '/api/venues/:id/match', async (req, params) => handleCreateMatch(req, env, params.id));
    router.add('GET', '/api/venues/:id/matches', async (req, params) => handleGetVenueMatches(req, env, params.id));
    router.add('POST', '/api/match/:id/join', async (req, params) => handleJoinMatch(req, env, params.id));

    // ===== Upload =====
    router.add('POST', '/api/upload', async (req) => handleUpload(req, env));
    router.add('POST', '/api/upload/batch', async (req) => handleBatchUpload(req, env));
    router.add('DELETE', '/api/upload', async (req) => handleDeleteFile(req, env));

    // ===== Clubs =====
    router.add('POST', '/api/clubs', async (req) => handleCreateClub(req, env));
    router.add('GET', '/api/clubs', async (req) => handleListClubs(req, env));
    router.add('GET', '/api/clubs/:id', async (req, params) => handleGetClub(req, env, params.id));
    router.add('POST', '/api/clubs/:id/update', async (req, params) => handleUpdateClub(req, env, params.id));
    router.add('POST', '/api/clubs/:id/certify', async (req, params) => handleClubCertification(req, env, params.id));
    router.add('POST', '/api/clubs/join', async (req) => handleJoinClub(req, env));
    router.add('POST', '/api/clubs/:id/join-request', async (req, params) => handleJoinRequest(req, env, params.id));
    router.add('GET', '/api/clubs/:id/join-requests', async (req, params) => handleListJoinRequests(req, env, params.id));
    router.add('POST', '/api/clubs/:id/join-request/:requestId/approve', async (req, params) => handleApproveJoinRequest(req, env, params.id, params.requestId));
    router.add('POST', '/api/clubs/:id/join-request/:requestId/reject', async (req, params) => handleRejectJoinRequest(req, env, params.id, params.requestId));
    router.add('POST', '/api/clubs/:id/messages', async (req, params) => handleSendClubMessage(req, env, params.id));
    router.add('GET', '/api/clubs/:id/messages', async (req, params) => handleGetClubMessages(req, env, params.id));

    // ===== Face Auth =====
    router.add('POST', '/api/face/detect', async (req) => handleDetectFace(req, env));
    router.add('POST', '/api/face/auth', async (req) => handleFaceAuth(req, env));

    // ===== Profile =====
    router.add('GET', '/api/users/me/tips', async (req) => handleMyTips(req, env));
    router.add('GET', '/api/users/me/badges', async (req) => handleMyBadges(req, env));
    router.add('GET', '/api/users/me/clubs', async (req) => handleMyClubs(req, env));
    router.add('GET', '/api/users/me/venues', async (req) => handleMyVenues(req, env));
    router.add('GET', '/api/users/me/invites', async (req) => handleMyInvites(req, env));
    router.add('GET', '/api/users/me/notifications', async (req) => handleNotifications(req, env));
    router.add('POST', '/api/users/me/notifications/read', async (req) => handleMarkRead(req, env));
    router.add('POST', '/api/users/me/avatar', async (req) => handleUpdateAvatar(req, env));
    router.add('POST', '/api/users/me/profile', async (req) => handleUpdateProfile(req, env));
    router.add('GET', '/api/users/me/level-info', async (req) => handleLevelInfo(req, env));

    // ===== Admin =====
    router.add('POST', '/api/admin/login', async (req) => handleAdminLogin(req, env));
    router.add('POST', '/api/admin/grant-chaihuo', async (req) => handleGrantChaihuo(req, env));
    router.add('GET', '/api/admin/stats', async (req) => handleDashboardStats(req, env));
    router.add('GET', '/api/admin/trend', async (req) => handleUserTrend(req, env));
    router.add('GET', '/api/rankings', async (req) => handleRankings(req, env));
    router.add('GET', '/api/admin/users', async (req) => handleAdminUsers(req, env));
    router.add('GET', '/api/admin/venues', async (req) => handleAdminVenues(req, env));
    router.add('POST', '/api/admin/venues/:venueId/approve', async (req, params) => handleAdminApproveVenue(req, env, params.venueId));
    router.add('POST', '/api/admin/venues/:id/delete', async (req, params) => handleAdminDeleteVenue(req, env, params.id));

    // ===== Owner Applications =====
    router.add('POST', '/api/venues/owner-apply', async (req) => handleOwnerApply(req, env));
    router.add('GET', '/api/admin/owner-applications', async (req) => handleAdminOwnerApplications(req, env));
    router.add('POST', '/api/admin/owner-applications/:id/approve', async (req, params) => handleAdminApproveOwnerApplication(req, env, params.id));
    router.add('POST', '/api/admin/owner-applications/:id/reject', async (req, params) => handleAdminRejectOwnerApplication(req, env, params.id));

    // ===== Admin Clubs =====
    router.add('GET', '/api/admin/clubs', async (req) => handleAdminClubs(req, env));
    router.add('GET', '/api/admin/club-certifications', async (req) => handleAdminClubCertifications(req, env));
    router.add('POST', '/api/admin/club-certifications/:id/approve', async (req, params) => handleAdminApproveClubCert(req, env, params.id));
    router.add('POST', '/api/admin/club-certifications/:id/reject', async (req, params) => handleAdminRejectClubCert(req, env, params.id));

    // 404
    router.add('ALL', '/*', () => {
      return jsonResponse({ error: 'Not Found', code: 404 }, 404);
    });

    return router.handle(request);
  },
};
