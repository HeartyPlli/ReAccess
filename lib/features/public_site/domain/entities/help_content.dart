class HelpQuestion {
  const HelpQuestion(this.question, this.answer);
  final String question;
  final String answer;
}

const helpQuestions = [
  HelpQuestion(
    'What is my school email?',
    'Your school email uses lastnamefirstname@gadtc.edu.ph. This is your school email format; please do not forget it. Contact the CISO Office if your assigned address differs.',
  ),
  HelpQuestion(
    'What is SSPR Enrollment?',
    'Self-Service Password Reset (SSPR) lets you reset your Office 365 password using recovery methods registered with your account. The CISO Office can help you enroll an alternative email and mobile number. Never share your password or verification codes in chat.',
  ),
  HelpQuestion(
    'How do I submit a request?',
    'Choose Student or Faculty on the home page to see the available services. Complete the form, verify your information, review it, and submit it for CISO Office review.',
  ),
  HelpQuestion(
    'What is Account Recovery?',
    'Account Recovery is assistance for students or faculty who can no longer access their institutional Office 365 account. Prepare a formal request letter and contact the CISO Office to verify your identity.',
  ),
  HelpQuestion(
    'What is Account Update?',
    'Account Update is a request to correct registered account information such as your name, email address, or contact number. The CISO Office must verify your identity before any changes are made.',
  ),
  HelpQuestion(
    'How will I know my request status?',
    'The CISO Office will confirm the contact method for your service request. For questions sent from this chat, reopen this chat in the same browser and check for an office reply. Email and SMS notifications are not available yet.',
  ),
  HelpQuestion(
    'What is my Student ID format?',
    'Your Student ID must contain exactly six numbers. Please do not send your ID or other personal records in this public chat.',
  ),
];
