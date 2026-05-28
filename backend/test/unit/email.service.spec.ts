/*
Testtype: Unit test
Omschrijving: Unit tests voor EmailService met gemockte SMTP-transport.
Doel: verifiëren dat transport geïnitialiseerd wordt en dat `sendPasswordResetEmail` mailt.
*/
jest.mock('nodemailer', () => ({
  createTransport: jest.fn(),
}));

import * as nodemailer from 'nodemailer';
import { EmailService } from '../../src/email/email.service';

describe('EmailService (unit)', () => {
  const OLD_ENV = process.env;

  beforeEach(() => {
    process.env = { ...OLD_ENV };
    process.env.SMTP_HOST = 'smtp.test';
    process.env.SMTP_PORT = '587';
    process.env.SMTP_FROM = 'noreply@test.local';
    process.env.SMTP_USER = 'user@test.local';
    process.env.SMTP_PASSWORD = 'password';
  });

  afterAll(() => {
    process.env = OLD_ENV;
    jest.resetAllMocks();
  });

  it('initializes transporter and sends password reset email', async () => {
    const sendMailMock = jest.fn().mockResolvedValue({});
    const verifyMock = jest.fn().mockResolvedValue(true);

    (nodemailer.createTransport as unknown as jest.Mock).mockReturnValue({
      sendMail: sendMailMock,
      verify: verifyMock,
    });

    const svc = new EmailService();
    await svc.onModuleInit();

    await svc.sendPasswordResetEmail('tester@example.com', 'token', 'https://app/reset?token=token');

    expect(nodemailer.createTransport).toHaveBeenCalled();
    expect(sendMailMock).toHaveBeenCalled();
  });
});
