-- CreateTable
CREATE TABLE "jap_comments" (
    "id" SERIAL NOT NULL,
    "entry_id" INTEGER NOT NULL,
    "author" TEXT,
    "text" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "jap_comments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "jap_comments_entry_id_idx" ON "jap_comments"("entry_id");

-- AddForeignKey
ALTER TABLE "jap_comments" ADD CONSTRAINT "jap_comments_entry_id_fkey" FOREIGN KEY ("entry_id") REFERENCES "jap_gpp_entries"("id") ON DELETE CASCADE ON UPDATE CASCADE;
