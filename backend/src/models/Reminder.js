import { v4 as uuidv4 } from 'uuid';

export class Reminder {
  constructor(data) {
    this.id = data.id || uuidv4();
    this.userId = data.userId;
    this.title = data.title;
    this.description = data.description || '';
    this.scheduledTime = data.scheduledTime; // ISO 8601
    this.createdAt = data.createdAt || new Date().toISOString();
    this.completedAt = data.completedAt || null;
    this.personality = data.personality || 'sarcastic'; // 'sarcastic', 'coach', 'friend'
    this.allowVoice = data.allowVoice || false;
    this.escalationLevel = data.escalationLevel || 0;
    this.status = data.status || 'pending'; // 'pending', 'completed', 'snoozed'
    this.snoozedUntil = data.snoozedUntil || null;
  }

  toJSON() {
    return {
      id: this.id,
      userId: this.userId,
      title: this.title,
      description: this.description,
      scheduledTime: this.scheduledTime,
      createdAt: this.createdAt,
      completedAt: this.completedAt,
      personality: this.personality,
      allowVoice: this.allowVoice,
      escalationLevel: this.escalationLevel,
      status: this.status,
      snoozedUntil: this.snoozedUntil
    };
  }

  static fromFirestore(doc) {
    return new Reminder(doc.data());
  }
}

export class EscalationHistory {
  constructor(data) {
    this.id = data.id || uuidv4();
    this.reminderId = data.reminderId;
    this.userId = data.userId;
    this.level = data.level; // 1, 2, 3, 4...
    this.action = data.action; // 'PUSH_NOTIFICATION', 'FULL_SCREEN_ALERT', 'VOICE_CALL', etc.
    this.triggeredAt = data.triggeredAt || new Date().toISOString();
    this.message = data.message;
    this.status = data.status || 'sent'; // 'sent', 'acknowledged', 'failed'
    this.metadata = data.metadata || {};
  }

  toJSON() {
    return {
      id: this.id,
      reminderId: this.reminderId,
      userId: this.userId,
      level: this.level,
      action: this.action,
      triggeredAt: this.triggeredAt,
      message: this.message,
      status: this.status,
      metadata: this.metadata
    };
  }
}
