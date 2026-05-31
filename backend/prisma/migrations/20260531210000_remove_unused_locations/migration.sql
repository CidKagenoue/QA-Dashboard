-- The dashboard manages vestigingen through Branch. The separate Location
-- concept is unused and can be removed without affecting other tables.
ALTER TABLE "maintenance_inspections" RENAME COLUMN "locationIds" TO "branchIds";

DROP TABLE IF EXISTS "Location";
