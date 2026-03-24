import { Injectable } from '@nestjs/common';
import * as nodemailer from 'nodemailer';

@Injectable()
export class EmailService {
  private transporter: nodemailer.Transporter;

  constructor() {
    // Configure Gmail SMTP
    const secure = process.env.SMTP_PORT === '465'; // Use secure (SSL) for port 465
    
    this.transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || 'localhost',
      port: parseInt(process.env.SMTP_PORT || '587'),
      secure: secure,
      auth: process.env.SMTP_USER ? {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASSWORD,
      } : undefined,
      // Disable certificate rejection for development
      // In production, remove this or handle properly
      tls: {
        rejectUnauthorized: false,
      },
    });
  }

  async sendPasswordResetEmail(
    email: string,
    resetToken: string,
    resetLink: string,
  ): Promise<void> {
    try {
      const mailOptions = {
        from: process.env.SMTP_FROM || 'noreply@qa-dashboard.local',
        to: email,
        subject: 'Wachtwoord opnieuw instellen - vlotter',
        html: this.getPasswordResetEmailTemplate(resetLink, resetToken),
      };

      await this.transporter.sendMail(mailOptions);
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
}
