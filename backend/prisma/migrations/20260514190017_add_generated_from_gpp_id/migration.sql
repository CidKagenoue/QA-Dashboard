-- AlterTable
ALTER TABLE "jap_gpp_entries" ADD COLUMN     "generated_from_gpp_id" INTEGER;

-- CreateIndex
CREATE INDEX "jap_gpp_entries_generated_from_gpp_id_idx" ON "jap_gpp_entries"("generated_from_gpp_id");
