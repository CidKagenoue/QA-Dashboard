CREATE TABLE "ova_tickets" (
    "id" SERIAL NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'draft',
    "current_step" INTEGER NOT NULL DEFAULT 1,
    "finding_date" TIMESTAMP(3),
    "ova_type" TEXT,
    "reasons" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "other_reason" TEXT,
    "incident_description" TEXT,
    "cause_analysis_method" TEXT,
    "cause_analysis_notes" TEXT,
    "follow_up_actions" TEXT,
    "effectiveness_notes" TEXT,
    "closure_notes" TEXT,
    "created_by_id" INTEGER NOT NULL,
    "last_edited_by_id" INTEGER NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ova_tickets_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ova_tickets_created_by_id_idx" ON "ova_tickets"("created_by_id");
CREATE INDEX "ova_tickets_last_edited_by_id_idx" ON "ova_tickets"("last_edited_by_id");

ALTER TABLE "ova_tickets"
ADD CONSTRAINT "ova_tickets_created_by_id_fkey"
FOREIGN KEY ("created_by_id") REFERENCES "users"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "ova_tickets"
ADD CONSTRAINT "ova_tickets_last_edited_by_id_fkey"
FOREIGN KEY ("last_edited_by_id") REFERENCES "users"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;
