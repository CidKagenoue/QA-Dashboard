// qa-login-backend/src/ova/ova-tickets.service.ts
import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from 'src/prisma/prisma.service';
import { UpdateOvaTicketDto } from './dto/update-ova-ticket.dto';

@Injectable()
export class OvaTicketsService {
  constructor(private readonly prisma: PrismaService) {}

  async update(id: number, dto: UpdateOvaTicketDto) {
    const existing = await this.prisma.ovaTicket.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`OVA ticket #${id} niet gevonden`);
    }

    const payload: any = {};
    
    if (dto.status !== undefined) payload.status = dto.status;
    if (dto.priority !== undefined) payload.priority = dto.priority;
    if (dto.description !== undefined) payload.incidentDescription = dto.description;
    if (dto.resolution !== undefined) payload.closureNotes = dto.resolution;

    const updated = await this.prisma.ovaTicket.update({
      where: { id },
      data: payload,
      include: {
        createdBy: true,      
        lastEditedBy: true,  
        closedBy: true,      
      },
    });

    return this.serialize(updated);
  }

  async remove(id: number) {
    const existing = await this.prisma.ovaTicket.findUnique({
      where: { id },
    });

    if (!existing) {
      throw new NotFoundException(`OVA ticket #${id} niet gevonden`);
    }

    if (existing.status !== 'closed' && existing.status !== 'completed') {
      throw new BadRequestException(
        'Alleen gesloten tickets kunnen verwijderd worden',
      );
    }

    return this.prisma.ovaTicket.delete({ where: { id } });
  }

  private serialize(ticket: any) {
    return {
      id: ticket.id,
      status: ticket.status,
      currentStep: ticket.currentStep,
      findingDate: ticket.findingDate?.toISOString() ?? null,
      ovaType: ticket.ovaType,
      reasons: ticket.reasons,
      otherReason: ticket.otherReason,
      incidentDescription: ticket.incidentDescription,
      causeAnalysisMethod: ticket.causeAnalysisMethod,
      causeAnalysisNotes: ticket.causeAnalysisNotes,
      followUpActions: ticket.followUpActions,
      effectivenessDate: ticket.effectivenessDate?.toISOString() ?? null,
      effectivenessNotes: ticket.effectivenessNotes,
      closureNotes: ticket.closureNotes,
      closedAt: ticket.closedAt?.toISOString() ?? null,
      createdAt: ticket.createdAt.toISOString(),
      updatedAt: ticket.updatedAt.toISOString(),
      createdBy: ticket.createdBy
        ? {
            id: ticket.createdBy.id,
            name: ticket.createdBy.name,
            email: ticket.createdBy.email,
          }
        : null,
      lastEditedBy: ticket.lastEditedBy
        ? {
            id: ticket.lastEditedBy.id,
            name: ticket.lastEditedBy.name,
            email: ticket.lastEditedBy.email,
          }
        : null,
      closedBy: ticket.closedBy
        ? {
            id: ticket.closedBy.id,
            name: ticket.closedBy.name,
            email: ticket.closedBy.email,
          }
        : null,
    };
  }
}