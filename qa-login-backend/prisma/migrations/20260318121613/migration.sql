-- CreateTable
CREATE TABLE "refresh_token_sessions" (
    "id" TEXT NOT NULL,
    "user_id" INTEGER NOT NULL,
    "token_hash" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "revoked_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refresh_token_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "refresh_token_sessions_token_hash_key" ON "refresh_token_sessions"("token_hash");

-- CreateIndex
CREATE INDEX "refresh_token_sessions_user_id_idx" ON "refresh_token_sessions"("user_id");

-- AddForeignKey
ALTER TABLE "refresh_token_sessions" ADD CONSTRAINT "refresh_token_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
