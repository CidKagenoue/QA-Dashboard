DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_tables WHERE tablename = 'executors'
  ) THEN
    EXECUTE 'ALTER TABLE "executors" ALTER COLUMN "updatedAt" DROP DEFAULT';
  END IF;
END
$$;
