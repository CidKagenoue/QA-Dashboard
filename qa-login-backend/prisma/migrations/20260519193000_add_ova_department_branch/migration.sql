ALTER TABLE "ova_tickets" ADD COLUMN IF NOT EXISTS "department_id" INTEGER;
ALTER TABLE "ova_tickets" ADD COLUMN IF NOT EXISTS "branch_id" INTEGER;

CREATE INDEX IF NOT EXISTS "ova_tickets_department_id_idx" ON "ova_tickets"("department_id");
CREATE INDEX IF NOT EXISTS "ova_tickets_branch_id_idx" ON "ova_tickets"("branch_id");

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'ova_tickets_department_id_fkey'
  ) THEN
    ALTER TABLE "ova_tickets"
      ADD CONSTRAINT "ova_tickets_department_id_fkey"
      FOREIGN KEY ("department_id") REFERENCES "Department"("id")
      ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'ova_tickets_branch_id_fkey'
  ) THEN
    ALTER TABLE "ova_tickets"
      ADD CONSTRAINT "ova_tickets_branch_id_fkey"
      FOREIGN KEY ("branch_id") REFERENCES "Branch"("id")
      ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;
