ALTER TABLE "users"
ADD COLUMN "is_admin" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "basis_access" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "whs_tours_access" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "ova_access" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "jap_gpp_access" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "maintenance_inspections_access" BOOLEAN NOT NULL DEFAULT false;
