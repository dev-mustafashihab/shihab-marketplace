-- Rename physical columns to snake_case (data-preserving RENAMEs only)

ALTER TABLE "users" RENAME COLUMN "passwordHash" TO "password_hash";
ALTER TABLE "users" RENAME COLUMN "failedAttempts" TO "failed_attempts";
ALTER TABLE "users" RENAME COLUMN "lockedUntil" TO "locked_until";
ALTER TABLE "users" RENAME COLUMN "lastLoginAt" TO "last_login_at";
ALTER TABLE "users" RENAME COLUMN "createdAt" TO "created_at";
ALTER TABLE "users" RENAME COLUMN "updatedAt" TO "updated_at";

ALTER TABLE "profiles" RENAME COLUMN "userId" TO "user_id";
ALTER TABLE "profiles" RENAME COLUMN "firstName" TO "first_name";
ALTER TABLE "profiles" RENAME COLUMN "lastName" TO "last_name";
ALTER TABLE "profiles" RENAME COLUMN "avatarMediaId" TO "avatar_media_id";
ALTER TABLE "profiles" RENAME COLUMN "createdAt" TO "created_at";
ALTER TABLE "profiles" RENAME COLUMN "updatedAt" TO "updated_at";

ALTER TABLE "roles" RENAME COLUMN "isSystem" TO "is_system";

ALTER TABLE "permissions" RENAME COLUMN "roleId" TO "role_id";

ALTER TABLE "refresh_tokens" RENAME COLUMN "userId" TO "user_id";
ALTER TABLE "refresh_tokens" RENAME COLUMN "tokenHash" TO "token_hash";
ALTER TABLE "refresh_tokens" RENAME COLUMN "familyId" TO "family_id";
ALTER TABLE "refresh_tokens" RENAME COLUMN "expiresAt" TO "expires_at";
ALTER TABLE "refresh_tokens" RENAME COLUMN "revokedAt" TO "revoked_at";
ALTER TABLE "refresh_tokens" RENAME COLUMN "replacedById" TO "replaced_by_id";
ALTER TABLE "refresh_tokens" RENAME COLUMN "userAgent" TO "user_agent";
ALTER TABLE "refresh_tokens" RENAME COLUMN "createdAt" TO "created_at";
ALTER TABLE "refresh_tokens" RENAME COLUMN "revokedReason" TO "revoked_reason";

ALTER TABLE "audit_logs" RENAME COLUMN "actorId" TO "actor_id";
ALTER TABLE "audit_logs" RENAME COLUMN "entityId" TO "entity_id";
ALTER TABLE "audit_logs" RENAME COLUMN "userAgent" TO "user_agent";
ALTER TABLE "audit_logs" RENAME COLUMN "createdAt" TO "created_at";
