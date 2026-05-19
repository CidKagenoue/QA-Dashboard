-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "NotificationModule" AS ENUM ('WHS_TOURS', 'OVA', 'JAP', 'MAINTENANCE');

-- CreateEnum
CREATE TYPE "NotificationType" AS ENUM ('OVA_TICKET_CREATED', 'OVA_ACTION_ASSIGNED', 'OVA_ACTION_REASSIGNED', 'OVA_TICKET_STATUS_CHANGED', 'ACCOUNT_CREATED', 'ACCOUNT_ACCESS_CHANGED', 'ACCOUNT_DELETED', 'PASSWORD_CHANGED', 'WHS_NEW_TASK', 'WHS_COMMENT', 'WHS_NEW_REPORT', 'OVA_DEADLINE', 'OVA_NEW_ACTION', 'OVA_1', 'OVA_2', 'OVA_3', 'JAP_NEW', 'JAP_COMMENT', 'JAP_STATUS_CHANGE', 'MAINTENANCE_NEW', 'MAINTENANCE_DUE', 'MAINTENANCE_STATUS_CHANGE');

-- CreateTable
CREATE TABLE "users" (
    "id" SERIAL NOT NULL,
    "email" TEXT NOT NULL,
    "password" TEXT NOT NULL,
    "name" TEXT,
    "is_admin" BOOLEAN NOT NULL DEFAULT false,
    "basis_access" BOOLEAN NOT NULL DEFAULT false,
    "whs_tours_access" BOOLEAN NOT NULL DEFAULT false,
    "ova_access" BOOLEAN NOT NULL DEFAULT false,
    "jap_gpp_access" BOOLEAN NOT NULL DEFAULT false,
    "maintenance_inspections_access" BOOLEAN NOT NULL DEFAULT false,
    "notifyWhsTours" BOOLEAN NOT NULL DEFAULT true,
    "notifyOva" BOOLEAN NOT NULL DEFAULT true,
    "notifyJapGpp" BOOLEAN NOT NULL DEFAULT true,
    "notifyMaintenance" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "profileImage" TEXT,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

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

-- CreateTable
CREATE TABLE "Department" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Department_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DepartmentLeader" (
    "id" SERIAL NOT NULL,
    "departmentId" INTEGER NOT NULL,
    "userId" INTEGER NOT NULL,

    CONSTRAINT "DepartmentLeader_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UserDepartment" (
    "userId" INTEGER NOT NULL,
    "departmentId" INTEGER NOT NULL,

    CONSTRAINT "UserDepartment_pkey" PRIMARY KEY ("userId","departmentId")
);

-- CreateTable
CREATE TABLE "password_reset_tokens" (
    "id" TEXT NOT NULL,
    "user_id" INTEGER NOT NULL,
    "token" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "used_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "password_reset_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ova_tickets" (
    "id" SERIAL NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'incomplete',
    "current_step" INTEGER NOT NULL DEFAULT 1,
    "finding_date" TIMESTAMP(3),
    "ova_type" TEXT,
    "reasons" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "other_reason" TEXT,
    "incident_description" TEXT,
    "cause_analysis_method" TEXT,
    "cause_analysis_notes" TEXT,
    "follow_up_actions" TEXT,
    "effectiveness_date" TIMESTAMP(3),
    "effectiveness_notes" TEXT,
    "closure_notes" TEXT,
    "closed_at" TIMESTAMP(3),
    "closed_by_id" INTEGER,
    "created_by_id" INTEGER NOT NULL,
    "last_edited_by_id" INTEGER NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ova_tickets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ova_external_contacts" (
    "id" SERIAL NOT NULL,
    "first_name" TEXT NOT NULL,
    "last_name" TEXT NOT NULL,
    "email" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ova_external_contacts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ova_follow_up_actions" (
    "id" SERIAL NOT NULL,
    "ticket_id" INTEGER NOT NULL,
    "type" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "due_date" TIMESTAMP(3) NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'nok',
    "assignee_type" TEXT NOT NULL,
    "internal_assignee_id" INTEGER,
    "external_contact_id" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ova_follow_up_actions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Branch" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Branch_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Location" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "branchId" INTEGER,

    CONSTRAINT "Location_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NotificationSetting" (
    "id" SERIAL NOT NULL,
    "userId" INTEGER NOT NULL,
    "module" "NotificationModule" NOT NULL,
    "type" "NotificationType" NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "email" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NotificationSetting_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" SERIAL NOT NULL,
    "recipient_user_id" INTEGER NOT NULL,
    "type" "NotificationType" NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "metadata" JSONB,
    "is_read" BOOLEAN NOT NULL DEFAULT false,
    "read_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "refresh_token_sessions_token_hash_key" ON "refresh_token_sessions"("token_hash");

-- CreateIndex
CREATE INDEX "refresh_token_sessions_user_id_idx" ON "refresh_token_sessions"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "password_reset_tokens_token_key" ON "password_reset_tokens"("token");

-- CreateIndex
CREATE INDEX "password_reset_tokens_user_id_idx" ON "password_reset_tokens"("user_id");

-- CreateIndex
CREATE INDEX "ova_tickets_created_by_id_idx" ON "ova_tickets"("created_by_id");

-- CreateIndex
CREATE INDEX "ova_tickets_last_edited_by_id_idx" ON "ova_tickets"("last_edited_by_id");

-- CreateIndex
CREATE INDEX "ova_tickets_closed_by_id_idx" ON "ova_tickets"("closed_by_id");

-- CreateIndex
CREATE INDEX "ova_external_contacts_name_idx" ON "ova_external_contacts"("last_name", "first_name");

-- CreateIndex
CREATE INDEX "ova_external_contacts_email_idx" ON "ova_external_contacts"("email");

-- CreateIndex
CREATE INDEX "ova_follow_up_actions_ticket_id_idx" ON "ova_follow_up_actions"("ticket_id");

-- CreateIndex
CREATE INDEX "ova_follow_up_actions_internal_assignee_id_idx" ON "ova_follow_up_actions"("internal_assignee_id");

-- CreateIndex
CREATE INDEX "ova_follow_up_actions_external_contact_id_idx" ON "ova_follow_up_actions"("external_contact_id");

-- CreateIndex
CREATE UNIQUE INDEX "NotificationSetting_userId_type_key" ON "NotificationSetting"("userId", "type");

-- CreateIndex
CREATE INDEX "notifications_recipient_is_read_idx" ON "notifications"("recipient_user_id", "is_read");

-- CreateIndex
CREATE INDEX "notifications_created_at_idx" ON "notifications"("created_at");

-- AddForeignKey
ALTER TABLE "refresh_token_sessions" ADD CONSTRAINT "refresh_token_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DepartmentLeader" ADD CONSTRAINT "DepartmentLeader_departmentId_fkey" FOREIGN KEY ("departmentId") REFERENCES "Department"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DepartmentLeader" ADD CONSTRAINT "DepartmentLeader_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserDepartment" ADD CONSTRAINT "UserDepartment_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserDepartment" ADD CONSTRAINT "UserDepartment_departmentId_fkey" FOREIGN KEY ("departmentId") REFERENCES "Department"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "password_reset_tokens" ADD CONSTRAINT "password_reset_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ova_tickets" ADD CONSTRAINT "ova_tickets_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ova_tickets" ADD CONSTRAINT "ova_tickets_last_edited_by_id_fkey" FOREIGN KEY ("last_edited_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ova_tickets" ADD CONSTRAINT "ova_tickets_closed_by_id_fkey" FOREIGN KEY ("closed_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ova_follow_up_actions" ADD CONSTRAINT "ova_follow_up_actions_ticket_id_fkey" FOREIGN KEY ("ticket_id") REFERENCES "ova_tickets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ova_follow_up_actions" ADD CONSTRAINT "ova_follow_up_actions_internal_assignee_id_fkey" FOREIGN KEY ("internal_assignee_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ova_follow_up_actions" ADD CONSTRAINT "ova_follow_up_actions_external_contact_id_fkey" FOREIGN KEY ("external_contact_id") REFERENCES "ova_external_contacts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Location" ADD CONSTRAINT "Location_branchId_fkey" FOREIGN KEY ("branchId") REFERENCES "Branch"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NotificationSetting" ADD CONSTRAINT "NotificationSetting_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_recipient_user_id_fkey" FOREIGN KEY ("recipient_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
