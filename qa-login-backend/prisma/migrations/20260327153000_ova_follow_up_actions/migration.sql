ALTER TABLE "ova_tickets"
ALTER COLUMN "status" DROP DEFAULT;

UPDATE "ova_tickets"
SET "status" = CASE
    WHEN LOWER("status") = 'completed' THEN 'closed'
    WHEN LOWER("status") = 'open' THEN 'open'
    WHEN LOWER("status") = 'closed' THEN 'closed'
    ELSE 'incomplete'
END;

ALTER TABLE "ova_tickets"
ADD COLUMN "effectiveness_date" TIMESTAMP(3),
ADD COLUMN "closed_at" TIMESTAMP(3),
ADD COLUMN "closed_by_id" INTEGER;

ALTER TABLE "ova_tickets"
ALTER COLUMN "status" SET DEFAULT 'incomplete';

CREATE INDEX "ova_tickets_closed_by_id_idx" ON "ova_tickets"("closed_by_id");

ALTER TABLE "ova_tickets"
ADD CONSTRAINT "ova_tickets_closed_by_id_fkey"
FOREIGN KEY ("closed_by_id") REFERENCES "users"("id")
ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "ova_external_contacts" (
    "id" SERIAL NOT NULL,
    "first_name" TEXT NOT NULL,
    "last_name" TEXT NOT NULL,
    "email" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ova_external_contacts_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ova_external_contacts_name_idx" ON "ova_external_contacts"("last_name", "first_name");
CREATE INDEX "ova_external_contacts_email_idx" ON "ova_external_contacts"("email");

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
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ova_follow_up_actions_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ova_follow_up_actions_ticket_id_idx" ON "ova_follow_up_actions"("ticket_id");
CREATE INDEX "ova_follow_up_actions_internal_assignee_id_idx" ON "ova_follow_up_actions"("internal_assignee_id");
CREATE INDEX "ova_follow_up_actions_external_contact_id_idx" ON "ova_follow_up_actions"("external_contact_id");

ALTER TABLE "ova_follow_up_actions"
ADD CONSTRAINT "ova_follow_up_actions_ticket_id_fkey"
FOREIGN KEY ("ticket_id") REFERENCES "ova_tickets"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ova_follow_up_actions"
ADD CONSTRAINT "ova_follow_up_actions_internal_assignee_id_fkey"
FOREIGN KEY ("internal_assignee_id") REFERENCES "users"("id")
ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "ova_follow_up_actions"
ADD CONSTRAINT "ova_follow_up_actions_external_contact_id_fkey"
FOREIGN KEY ("external_contact_id") REFERENCES "ova_external_contacts"("id")
ON DELETE SET NULL ON UPDATE CASCADE;
