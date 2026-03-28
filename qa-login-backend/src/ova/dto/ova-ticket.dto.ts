export class OvaExternalResponsibleDto {
  id?: number;
  firstName?: string | null;
  lastName?: string | null;
  email?: string | null;
}

export class OvaFollowUpActionDto {
  id?: number;
  type?: string | null;
  description?: string | null;
  dueDate?: string | null;
  status?: string | null;
  assigneeType?: string | null;
  internalAssigneeId?: number | null;
  externalResponsible?: OvaExternalResponsibleDto | null;
}

export class UpdateOvaFollowUpActionDto {
  status?: string | null;
}

export class CreateOvaTicketDto {
  findingDate?: string | null;
  ovaType?: string | null;
  reasons?: string[];
  otherReason?: string | null;
  incidentDescription?: string | null;
  causeAnalysisMethod?: string | null;
  causeAnalysisNotes?: string | null;
  followUpActions?: string | null;
  actions?: OvaFollowUpActionDto[];
  effectivenessDate?: string | null;
  effectivenessNotes?: string | null;
  closureNotes?: string | null;
  currentStep?: number;
  status?: string;
}

export class UpdateOvaTicketDto extends CreateOvaTicketDto {}
