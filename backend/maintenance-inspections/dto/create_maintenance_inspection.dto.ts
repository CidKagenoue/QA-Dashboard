export class CreateMaintenanceInspectionDto {
  equipment?: string;
  inspectionType?: string;
  inspectionInstitution?: string;
  contactInfo?: string | null;
  locationIds?: number[];
  frequency?: string;
  selfContact?: boolean;
  lastInspectionDate?: string | null;
  dueDate?: string;
  status?: string | null;
  notes?: string | null;
}

export class UpdateMaintenanceInspectionDto extends CreateMaintenanceInspectionDto {}
