CREATE TABLE "maintenance_inspection_branches" (
    "maintenance_inspection_id" INTEGER NOT NULL,
    "branch_id" INTEGER NOT NULL,

    CONSTRAINT "maintenance_inspection_branches_pkey" PRIMARY KEY ("maintenance_inspection_id", "branch_id")
);

CREATE INDEX "maintenance_inspection_branches_branch_id_idx"
ON "maintenance_inspection_branches"("branch_id");

ALTER TABLE "maintenance_inspection_branches"
ADD CONSTRAINT "maintenance_inspection_branches_maintenance_inspection_id_fkey"
FOREIGN KEY ("maintenance_inspection_id")
REFERENCES "maintenance_inspections"("id")
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE "maintenance_inspection_branches"
ADD CONSTRAINT "maintenance_inspection_branches_branch_id_fkey"
FOREIGN KEY ("branch_id")
REFERENCES "Branch"("id")
ON DELETE RESTRICT
ON UPDATE CASCADE;

INSERT INTO "maintenance_inspection_branches" ("maintenance_inspection_id", "branch_id")
SELECT inspection."id", branch_id
FROM "maintenance_inspections" AS inspection
CROSS JOIN LATERAL unnest(inspection."branchIds") AS branch_id
ON CONFLICT DO NOTHING;

ALTER TABLE "maintenance_inspections" DROP COLUMN "branchIds";
