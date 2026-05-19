import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import * as nodemailer from 'nodemailer';

@Injectable()
export class EmailService implements OnModuleInit {
  private readonly logger = new Logger(EmailService.name);
  private readonly transporter?: nodemailer.Transporter;
  private readonly fromAddress: string;
  private readonly smtpConfigured: boolean;

  constructor() {
    const host = this.readEnv('SMTP_HOST');
    const port = Number(this.readEnv('SMTP_PORT') || '587');
    const secure = this.readBooleanEnv('SMTP_SECURE') ?? port === 465;
    const user = this.readEnv('SMTP_USER');
    const pass = this.readEnv('SMTP_PASSWORD');
    const ignoreTlsErrors = this.readBooleanEnv('SMTP_IGNORE_TLS_ERRORS') ?? false;

    this.fromAddress =
      this.readEnv('SMTP_FROM') || this.readEnv('MAIL_FROM') || 'noreply@qa-dashboard.local';

    if (!host) {
      this.smtpConfigured = false;
      this.logger.warn(
        'SMTP is not configured. Set SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD and SMTP_FROM in backend/.env.',
      );
      return;
    }

    if (!Number.isFinite(port) || port <= 0) {
      throw new Error('SMTP_PORT must be a valid positive number.');
    }

    if ((user && !pass) || (!user && pass)) {
      throw new Error('SMTP_USER and SMTP_PASSWORD must be set together.');
    }

    this.transporter = nodemailer.createTransport({
      host,
      port,
      secure,
      auth: user && pass ? { user, pass } : undefined,
      tls: {
        rejectUnauthorized: !ignoreTlsErrors,
      },
    });
    this.smtpConfigured = true;
  }

  async onModuleInit(): Promise<void> {
    if (!this.smtpConfigured || !this.transporter) {
      return;
    }

    try {
      await this.transporter.verify();
      this.logger.log('SMTP connection verified successfully.');
    } catch (error: any) {
      this.logger.error(
        `SMTP verification failed: ${error?.message || 'unknown error'}. Email sending will fail until SMTP settings are fixed.`,
      );
    }
  }

  async sendPasswordResetEmail(
    email: string,
    resetToken: string,
    resetLink: string,
  ): Promise<void> {
    try {
      this.ensureSmtpConfigured();

      const mailOptions = {
        from: this.fromAddress,
        to: email,
        subject: 'Wachtwoord opnieuw instellen - vlotter',
        html: this.getPasswordResetEmailTemplate(resetLink, resetToken),
      };

      await this.transporter!.sendMail(mailOptions);
      console.log(`Reset e-mail verzonden naar ${email}`);
    } catch (error: any) {
      console.error('Fout bij verzenden reset e-mail:', error);

      if (error?.code === 'EAUTH' || error?.responseCode === 535) {
        throw new Error(
          'Gmail login mislukt. Zet SMTP_USER op je Gmail-adres en SMTP_PASSWORD op een Google App Password (16 tekens, zonder spaties).',
        );
      }

      throw new Error(
        `Verzenden van reset e-mail mislukt: ${error?.message || 'onbekende fout'}`,
      );
    }
  }

  async sendNotificationEmail(
    email: string,
    title: string,
    body: string,
    type?: string,
    module?: string,
    metadata?: any,
  ): Promise<void> {
    try {
      this.ensureSmtpConfigured();

      const mailOptions = {
        from: this.fromAddress,
        to: email,
        subject: title,
        html: this.getNotificationEmailTemplate(
          title,
          body,
          type,
          module,
          metadata,
        ),
      };

      await this.transporter!.sendMail(mailOptions);
      console.log(`Notificatie e-mail verzonden naar ${email}`);
    } catch (error: any) {
      console.error('Fout bij verzenden notificatie e-mail:', error);
      // Don't throw - notification should still be created even if email fails
    }
  }

  private ensureSmtpConfigured(): void {
    if (!this.smtpConfigured || !this.transporter) {
      throw new Error(
        'SMTP is niet geconfigureerd op de server. Stel SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD en SMTP_FROM in.',
      );
    }
  }

  private readEnv(name: string): string {
    return process.env[name]?.trim() || '';
  }

  private readBooleanEnv(name: string): boolean | undefined {
    const value = this.readEnv(name).toLowerCase();
    if (!value) {
      return undefined;
    }

    if (value === '1' || value === 'true' || value === 'yes' || value === 'on') {
      return true;
    }

    if (value === '0' || value === 'false' || value === 'no' || value === 'off') {
      return false;
    }

    throw new Error(`${name} must be true/false, 1/0, yes/no or on/off.`);
  }

  private getPasswordResetEmailTemplate(resetLink: string, token: string): string {
    return `
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Wachtwoord opnieuw instellen</title>
          <style>
            body {
              font-family: Arial, sans-serif;
              background-color: #f2f7ea;
              margin: 0;
              padding: 0;
            }
            .container {
              max-width: 600px;
              margin: 20px auto;
              background-color: #ffffff;
              border-radius: 10px;
              border: 1px solid #dce8c8;
              box-shadow: 0 8px 24px rgba(76, 117, 34, 0.12);
              overflow: hidden;
            }
            .header {
              background: linear-gradient(90deg, #7CB342, #8BC34A);
              color: white;
              padding: 24px;
              text-align: center;
            }
            .brand {
              font-size: 28px;
              font-weight: 700;
              letter-spacing: 0.5px;
              margin: 0;
            }
            .content {
              padding: 24px;
              color: #2f3a1f;
              line-height: 1.5;
            }
            .button {
              display: inline-block;
              padding: 12px 24px;
              background-color: #7CB342;
              color: white;
              text-decoration: none;
              border-radius: 8px;
              margin-top: 18px;
              font-weight: 700;
            }
            .footer {
              margin-top: 20px;
              padding-top: 20px;
              border-top: 1px solid #e8efd9;
              font-size: 12px;
              color: #6b7a52;
              text-align: center;
            }
            .code {
              background-color: #f6faee;
              border: 1px dashed #c6db9b;
              padding: 10px;
              border-radius: 6px;
              font-family: monospace;
              margin-top: 10px;
              word-break: break-all;
            }
            .meta {
              margin-top: 14px;
              font-size: 13px;
              color: #5c6e3d;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <p class="brand">vlotter</p>
              <h1 style="margin: 8px 0 0; font-size: 22px;">Wachtwoord opnieuw instellen</h1>
            </div>
            <div class="content">
              <p>Hallo,</p>
              <p>We hebben een aanvraag ontvangen om je wachtwoord te wijzigen.</p>
              <p>Klik op de knop hieronder om je wachtwoord opnieuw in te stellen. Deze link is 1 uur geldig.</p>
              <a href="${resetLink}" class="button">Nieuw wachtwoord instellen</a>
              <p class="meta">Werkt de knop niet? Kopieer dan deze link in je browser:</p>
              <p class="code">${resetLink}</p>
              <p class="meta"><strong>Veiligheidscode:</strong> ${token}</p>
              <div class="footer">
                <p>Heb je dit niet aangevraagd? Dan kun je deze e-mail negeren.</p>
                <p>© 2026 vlotter. Alle rechten voorbehouden.</p>
              </div>
            </div>
          </div>
        </body>
      </html>
    `;
  }

  private getNotificationEmailTemplate(
    title: string,
    body: string,
    type?: string,
    module?: string,
    metadata?: any,
  ): string {
    const timestamp = new Date().toLocaleString('nl-NL', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });

    // Filter metadata to only show useful fields
    const usefulMetadata = this.filterUsefulMetadata(metadata);

    let metadataHtml = '';
    if (usefulMetadata && Object.keys(usefulMetadata).length > 0) {
      metadataHtml = `
        <div style="margin-top: 20px; padding: 16px; background-color: #f9fbf5; border-left: 4px solid #7CB342; border-radius: 4px;">
          <h4 style="margin: 0 0 12px 0; font-size: 14px; font-weight: 700; color: #7CB342;">Details:</h4>
      `;
      for (const [key, value] of Object.entries(usefulMetadata)) {
        const displayKey = this.formatMetadataKey(key);
        metadataHtml += `
          <p style="margin: 6px 0; font-size: 13px; color: #5c6e3d;">
            <strong>${displayKey}:</strong> ${this.formatMetadataValue(value)}
          </p>
        `;
      }
      metadataHtml += `</div>`;
    }

    return `
      <!DOCTYPE html>
      <html lang="nl">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>${title}</title>
          <style>
            body {
              font-family: Arial, sans-serif;
              background-color: #f2f7ea;
              margin: 0;
              padding: 0;
            }
            .container {
              max-width: 600px;
              margin: 20px auto;
              background-color: #ffffff;
              border-radius: 10px;
              border: 1px solid #dce8c8;
              box-shadow: 0 8px 24px rgba(76, 117, 34, 0.12);
              overflow: hidden;
            }
            .header {
              background: linear-gradient(90deg, #7CB342, #8BC34A);
              color: white;
              padding: 24px;
              text-align: center;
            }
            .brand {
              font-size: 28px;
              font-weight: 700;
              letter-spacing: 0.5px;
              margin: 0;
            }
            .subheader {
              font-size: 13px;
              opacity: 0.9;
              margin-top: 8px;
            }
            .content {
              padding: 24px;
              color: #2f3a1f;
              line-height: 1.6;
            }
            .module-badge {
              display: inline-block;
              background-color: #e8f5e9;
              color: #558b2f;
              padding: 6px 12px;
              border-radius: 20px;
              font-size: 12px;
              font-weight: 600;
              margin-bottom: 12px;
            }
            .notification-title {
              font-size: 20px;
              font-weight: 700;
              margin: 0 0 8px 0;
              color: #7CB342;
            }
            .notification-type {
              font-size: 12px;
              color: #8bc34a;
              margin-bottom: 16px;
              text-transform: uppercase;
              letter-spacing: 0.5px;
            }
            .notification-body {
              font-size: 14px;
              color: #2f3a1f;
              margin: 16px 0;
              line-height: 1.8;
            }
            .meta-info {
              margin-top: 16px;
              padding-top: 16px;
              border-top: 1px solid #e8efd9;
              font-size: 12px;
              color: #7a8a5a;
            }
            .timestamp {
              display: block;
              margin-top: 4px;
            }
            .footer {
              margin-top: 20px;
              padding-top: 20px;
              border-top: 1px solid #e8efd9;
              font-size: 11px;
              color: #9cac7d;
              text-align: center;
            }
            .cta-button {
              display: inline-block;
              background-color: #7CB342;
              color: white;
              padding: 10px 20px;
              text-decoration: none;
              border-radius: 6px;
              margin-top: 12px;
              font-size: 14px;
              font-weight: 600;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <p class="brand">vlotter</p>
              <p class="subheader">Meldingen</p>
            </div>
            <div class="content">
              ${module ? `<span class="module-badge">${module}</span>` : ''}
              <h2 class="notification-title">${title}</h2>
              ${type ? `<p class="notification-type">${type}</p>` : ''}
              <p class="notification-body">${body}</p>
              ${metadataHtml}
              <div class="meta-info">
                <strong>Ontvangen:</strong>
                <span class="timestamp">${timestamp}</span>
              </div>
              <div style="text-align: center; margin-top: 20px;">
                <a href="${this.resolvePublicFrontendUrl()}" class="cta-button">
                  Bekijk in vlotter
                </a>
              </div>
              <div class="footer">
                <p>© 2026 vlotter. Alle rechten voorbehouden.</p>
                <p>Je ontvangt deze e-mail omdat je meldingen via e-mail hebt ingeschakeld in je instellingen.</p>
              </div>
            </div>
          </div>
        </body>
      </html>
    `;
  }

  private filterUsefulMetadata(metadata: any): Record<string, any> {
    if (!metadata || typeof metadata !== 'object') {
      return {};
    }

    const uselessFields = [
      'entryId',
      'japEntryId',
      'gppEntryId',
      'entry_id',
      'id',
      'source',
    ];

    const usefulFields = [
      'createdBy',
      'createdByName',
      'createdByUser',
      'userName',
      'userEmail',
      'ticketId',
      'ticket_id',
      'actionId',
      'action_id',
      'accountId',
      'account_id',
      'departmentName',
      'department_name',
      'status',
      'priority',
      'description',
      'reason',
      'type',
    ];

    const filtered: Record<string, any> = {};

    // First, add useful fields that exist
    for (const field of usefulFields) {
      if (metadata[field] !== undefined && metadata[field] !== null) {
        filtered[field] = metadata[field];
      }
    }

    // Then, add any other fields not in useless list
    for (const [key, value] of Object.entries(metadata)) {
      if (
        !uselessFields.includes(key) &&
        !usefulFields.includes(key) &&
        value !== undefined &&
        value !== null &&
        value !== ''
      ) {
        filtered[key] = value;
      }
    }

    return filtered;
  }

  private formatMetadataKey(key: string): string {
    // Handle special cases
    const specialCases: Record<string, string> = {
      createdBy: 'Gemaakt door (ID)',
      createdByName: 'Gemaakt door',
      createdByUser: 'Gemaakt door',
      userName: 'Persoon',
      userEmail: 'E-mailadres',
      ticketId: 'Ticket',
      ticket_id: 'Ticket',
      actionId: 'Actie ID',
      action_id: 'Actie ID',
      accountId: 'Account',
      account_id: 'Account',
      departmentName: 'Afdeling',
      department_name: 'Afdeling',
    };

    if (specialCases[key]) {
      return specialCases[key];
    }

    // Default: convert camelCase/snake_case to readable format
    return key
      .replace(/([A-Z])/g, ' $1')
      .replace(/_/g, ' ')
      .replace(/^./, (str) => str.toUpperCase())
      .trim();
  }

  private formatMetadataValue(value: any): string {
    if (typeof value === 'boolean') {
      return value ? 'Ja' : 'Nee';
    }
    if (typeof value === 'object') {
      return JSON.stringify(value, null, 2);
    }
    return String(value);
  }

  private resolvePublicFrontendUrl(): string {
    const configuredUrl =
      process.env.PUBLIC_FRONTEND_URL || process.env.FRONTEND_URL || '';
    const baseUrl = configuredUrl.trim();

    if (!baseUrl) {
      return 'https://vlotter.local';
    }

    return baseUrl.replace(/\/+$/, '');
  }
}
