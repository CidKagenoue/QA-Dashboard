export class CreateOvaTicketDto {
  findingDate?: string | null;
  ovaType?: string | null;
  reasons?: string[];
  otherReason?: string | null;
  incidentDescription?: string | null;
  currentStep?: number;
}

export class UpdateOvaTicketDto extends CreateOvaTicketDto {}
