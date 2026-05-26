ALTER TABLE "ova_tickets" ADD COLUMN IF NOT EXISTS "department_fallback" TEXT;
ALTER TABLE "ova_tickets" ADD COLUMN IF NOT EXISTS "branch_fallback" TEXT;

UPDATE "ova_tickets" t
SET "branch_fallback" = 'unknown',
    "branch_id" = NULL
FROM "Branch" b
WHERE t."branch_id" = b."id"
  AND lower(b."name") = lower('Ander');

UPDATE "ova_tickets" t
SET "department_fallback" = 'unknown',
    "department_id" = NULL
FROM "Department" d
WHERE t."department_id" = d."id"
  AND lower(d."name") = lower('Ander');

DELETE FROM "BranchDepartment"
WHERE "branchId" IN (SELECT "id" FROM "Branch" WHERE lower("name") = lower('Ander'))
   OR "departmentId" IN (SELECT "id" FROM "Department" WHERE lower("name") = lower('Ander'));

DELETE FROM "DepartmentLeader"
WHERE "departmentId" IN (SELECT "id" FROM "Department" WHERE lower("name") = lower('Ander'));

DELETE FROM "UserDepartment"
WHERE "departmentId" IN (SELECT "id" FROM "Department" WHERE lower("name") = lower('Ander'));

DELETE FROM "Location"
WHERE "branchId" IN (SELECT "id" FROM "Branch" WHERE lower("name") = lower('Ander'));

DELETE FROM "Branch" WHERE lower("name") = lower('Ander');
DELETE FROM "Department" WHERE lower("name") = lower('Ander');
