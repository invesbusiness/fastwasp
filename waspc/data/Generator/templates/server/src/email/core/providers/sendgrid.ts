import SendGrid from "@sendgrid/mail";
import { getDefaultFromField } from "../helpers.js";
import type { SendGridProvider, EmailSender } from "../types.js";

export function initSendGridEmailSender(
  provider: SendGridProvider
): EmailSender {
  SendGrid.setApiKey(provider.apiKey);

  const defaultFromField = getDefaultFromField();

  return {
    async send(email) {
      const fromField = email.from || defaultFromField;
      return SendGrid.send({
        from: {
          email: fromField.email,
          name: fromField.title,
        },
        to: email.to,
        subject: email.subject,
        text: email.text,
        html: email.html,
      });
    },
  };
}
