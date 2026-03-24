/**
 * NLP Parser: Parse natural language reminders (Hebrew + English)
 * 
 * Examples:
 * "Call Hezi tonight" → { title: "Call Hezi", time: "20:00", date: today }
 * "Meeting with boss tomorrow at 2pm" → { title: "Meeting with boss", time: "14:00", date: tomorrow }
 * "Buy groceries in 1 hour" → { title: "Buy groceries", time: now + 1h }
 * "להתקשר לגל ב-7 ורבע בערב" → { title: "להתקשר לגל", time: "19:15", date: today }
 * "לקנות חלב מחר בבוקר" → { title: "לקנות חלב", time: "09:00", date: tomorrow }
 */

// Israel timezone
const TIMEZONE = 'Asia/Jerusalem';

function nowInIsrael() {
  return new Date(new Date().toLocaleString('en-US', { timeZone: TIMEZONE }));
}

export class NLPParser {
  /**
   * Parse natural language reminder text
   * Returns: { title, scheduledTime (ISO 8601), confidence }
   */
  parse(text) {
    if (!text || text.trim().length === 0) {
      throw new Error('Empty reminder text');
    }

    // Detect language
    const isHebrew = /[\u0590-\u05FF]/.test(text);

    // Extract time and title
    const timeMatch = isHebrew ? this.extractTimeHebrew(text) : this.extractTime(text);
    const title = isHebrew ? this.extractTitleHebrew(text, timeMatch) : this.extractTitle(text, timeMatch);

    if (!timeMatch || (!timeMatch.time && !timeMatch.relative)) {
      throw new Error('Could not extract time from reminder');
    }

    const scheduledTime = this.calculateDateTime(
      timeMatch.time,
      timeMatch.date,
      timeMatch.relative
    );

    return {
      title: title,
      scheduledTime: scheduledTime.toISOString(),
      confidence: timeMatch.confidence || 0.8,
      metadata: {
        originalText: text,
        parsedTime: timeMatch.time,
        parsedDate: timeMatch.date,
        relative: timeMatch.relative
      }
    };
  }

  // ─── Hebrew Time Parsing ───────────────────────────────────────────

  /**
   * Extract time from Hebrew text
   */
  extractTimeHebrew(text) {
    const unitMap = { 'דקה': 'minute', 'דקות': 'minute', 'דק׳': 'minute',
                      'שעה': 'hour', 'שעות': 'hour',
                      'יום': 'day', 'ימים': 'day' };

    // Relative: "בעוד X דקות/שעות" OR "עוד X דקות/שעות" (with arabic numerals)
    const relativeMatch = text.match(/(?:בעוד|עוד)\s+(\d+)\s+(דקות?|דק׳?|שעות?|ימים|יום)/);
    if (relativeMatch) {
      const value = parseInt(relativeMatch[1]);
      const unit = unitMap[relativeMatch[2]] || 'minute';
      return { relative: { value, unit }, confidence: 0.95 };
    }

    // Relative: "בעוד/עוד X דקות/שעות" with Hebrew word numbers
    const hebrewNums = {
      'אחת': 1, 'אחד': 1, 'שתי': 2, 'שתיים': 2, 'שני': 2,
      'שלוש': 3, 'שלושה': 3, 'ארבע': 4, 'ארבעה': 4,
      'חמש': 5, 'חמישה': 5, 'שש': 6, 'שישה': 6,
      'שבע': 7, 'שבעה': 7, 'שמונה': 8, 'תשע': 9, 'תשעה': 9, 'עשר': 10, 'עשרה': 10,
      'עשרים': 20, 'שלושים': 30, 'ארבעים': 40, 'חמישים': 50
    };
    const hebrewNumKeys = Object.keys(hebrewNums).join('|');
    const wordNumRegex = new RegExp(`(?:בעוד|עוד)\\s+(${hebrewNumKeys})\\s+(דקות?|דק׳?|שעות?)`);
    const wordNumMatch = text.match(wordNumRegex);
    if (wordNumMatch) {
      const value = hebrewNums[wordNumMatch[1]];
      const unit = unitMap[wordNumMatch[2]] || 'minute';
      return { relative: { value, unit }, confidence: 0.95 };
    }

    // Relative: "בעוד/עוד שעה/חצי שעה/רבע שעה"
    const relWordMatch = text.match(/(?:בעוד|עוד)\s+(חצי שעה|רבע שעה|שעה)/);
    if (relWordMatch) {
      const map = { 'שעה': 60, 'חצי שעה': 30, 'רבע שעה': 15 };
      return { relative: { value: map[relWordMatch[1]], unit: 'minute' }, confidence: 0.95 };
    }

    // Detect AM/PM from Hebrew context
    const isEvening = /בערב|אחה"צ|אחרי הצהריים|אחרי הצהרים/.test(text);
    const isMorning = /בבוקר|בצהריים/.test(text);
    const isNight = /בלילה/.test(text);

    // "ב-7 ורבע" / "בשעה 7 ורבע" / "ב-7:15" / "בשעה 19:15"
    const timePatterns = [
      // "בשעה 7 ורבע" / "ב-7 ורבע" / "לשעה 7 ורבע"
      /(?:[בל]שעה\s+|ב-?)(\d{1,2})\s+ורבע/,
      // "בשעה 7 וחצי" / "ב-7 וחצי" / "לשעה 7 וחצי"
      /(?:[בל]שעה\s+|ב-?)(\d{1,2})\s+וחצי/,
      // "בשעה 7:15" / "ב-7:15" / "לשעה 19:15"
      /(?:[בל]שעה\s+|ב-?)(\d{1,2}):(\d{2})/,
      // "בשעה 7" / "ב-7" / "לשעה 7"
      /(?:[בל]שעה\s+|ב-?)(\d{1,2})(?!\d|:|\s+ו)/,
    ];

    for (let i = 0; i < timePatterns.length; i++) {
      const match = text.match(timePatterns[i]);
      if (match) {
        let hours = parseInt(match[1]);
        let minutes = 0;

        if (i === 0) minutes = 15;       // ורבע
        else if (i === 1) minutes = 30;   // וחצי
        else if (i === 2) minutes = parseInt(match[2]); // explicit minutes

        // Adjust AM/PM based on Hebrew context
        if (hours <= 12) {
          if (isEvening && hours < 12) hours += 12;
          else if (isNight) { if (hours < 12) hours += 12; if (hours === 24) hours = 0; }
          else if (!isMorning && hours >= 1 && hours <= 6) hours += 12; // default to PM for small hours
        }

        const time = `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;

        // Detect date
        const date = this.extractDateHebrew(text);

        return { time, date, confidence: 0.9 };
      }
    }

    // "הערב" / "הלילה"  (no specific time)
    if (/הערב|הלילה/.test(text)) {
      return { time: '20:00', date: 'today', confidence: 0.7 };
    }

    // "מחר בבוקר" (no specific time)
    if (/מחר/.test(text)) {
      return { time: isMorning ? '09:00' : '09:00', date: 'tomorrow', confidence: 0.7 };
    }

    // Fallback — look for any number that could be an hour
    const fallbackMatch = text.match(/(\d{1,2})/);
    if (fallbackMatch) {
      let h = parseInt(fallbackMatch[1]);
      if (isEvening && h < 12) h += 12;
      const date = this.extractDateHebrew(text);
      return { time: `${String(h).padStart(2, '0')}:00`, date, confidence: 0.5 };
    }

    // Last resort
    return { time: '09:00', date: this.extractDateHebrew(text), confidence: 0.3 };
  }

  /**
   * Extract date from Hebrew text
   */
  extractDateHebrew(text) {
    if (/מחר/.test(text)) return 'tomorrow';
    if (/מחרתיים/.test(text)) return 'day_after_tomorrow';

    // Days of week in Hebrew
    const hebrewDays = {
      'ראשון': 'sunday', 'שני': 'monday', 'שלישי': 'tuesday',
      'רביעי': 'wednesday', 'חמישי': 'thursday', 'שישי': 'friday', 'שבת': 'saturday'
    };
    for (const [heb, eng] of Object.entries(hebrewDays)) {
      if (text.includes(`יום ${heb}`) || text.includes(`ביום ${heb}`)) return eng;
    }

    return 'today';
  }

  /**
   * Extract title from Hebrew text (remove time references)
   */
  extractTitleHebrew(text, _timeMatch) {
    let title = text;

    // Remove time patterns
    title = title.replace(/בעוד\s+(?:\d+\s+)?(?:דקות?|דק׳?|שעות?|ימים|יום|חצי שעה|רבע שעה|שעה)/g, '');
    title = title.replace(/(?:בשעה\s+|ב-?)\d{1,2}(?::\d{2})?\s*(?:ורבע|וחצי)?/g, '');
    title = title.replace(/בערב|בבוקר|בלילה|בצהריים|אחה"צ|אחרי הצהריים|אחרי הצהרים|הערב|הלילה/g, '');
    title = title.replace(/מחרתיים|מחר|היום/g, '');
    title = title.replace(/ביום\s+(?:ראשון|שני|שלישי|רביעי|חמישי|שישי|שבת)/g, '');

    title = title.replace(/\s+/g, ' ').trim();
    return title || 'תזכורת';
  }

  // ─── English Time Parsing (original) ───────────────────────────────

  /**
   * Extract time from text
   */
  extractTime(text) {
    const lowText = text.toLowerCase();

    // Check for relative time: "in X hours/minutes"
    const inPattern = /in\s+(\d+)\s+(hour|minute|day)/i;
    const inMatch = text.match(inPattern);
    if (inMatch) {
      return {
        relative: { value: parseInt(inMatch[1]), unit: inMatch[2] },
        confidence: 0.95
      };
    }

    // Check for today/tonight
    if (/tonight|today evening|this evening/i.test(lowText)) {
      return {
        time: '20:00', // Default evening time
        date: 'today',
        confidence: 0.8
      };
    }

    // Check for tomorrow
    if (/tomorrow|next day/i.test(lowText)) {
      return {
        time: this.extractSpecificTime(text) || '09:00',
        date: 'tomorrow',
        confidence: 0.85
      };
    }

    // Check for specific time: "at 2pm", "at 14:00"
    const timePattern = /(?:at|@)\s*(\d{1,2}):?(\d{2})?\s*(am|pm)?/i;
    const timeMatch = text.match(timePattern);
    if (timeMatch) {
      return {
        time: this.parseTime(timeMatch[1], timeMatch[2], timeMatch[3]),
        date: 'today',
        confidence: 0.95
      };
    }

    // Check for day of week: "Monday", "Friday"
    const dayPattern = /\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/i;
    const dayMatch = text.match(dayPattern);
    if (dayMatch) {
      return {
        time: this.extractSpecificTime(text) || '09:00',
        date: dayMatch[1].toLowerCase(),
        confidence: 0.85
      };
    }

    // Default: assume today at 9am
    return {
      time: '09:00',
      date: 'today',
      confidence: 0.5
    };
  }

  /**
   * Extract specific time from text (e.g., "2pm", "14:30")
   */
  extractSpecificTime(text) {
    const timePattern = /(\d{1,2}):?(\d{2})?\s*(am|pm)?/i;
    const match = text.match(timePattern);
    if (match) {
      return this.parseTime(match[1], match[2], match[3]);
    }
    return null;
  }

  /**
   * Parse time components into HH:MM format
   */
  parseTime(hours, minutes = '00', meridiem) {
    let h = parseInt(hours);
    const m = minutes ? parseInt(minutes) : 0;

    if (meridiem) {
      if (meridiem.toLowerCase() === 'pm' && h !== 12) h += 12;
      if (meridiem.toLowerCase() === 'am' && h === 12) h = 0;
    }

    return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
  }

  /**
   * Extract title from text (remove time references)
   */
  extractTitle(text, timeMatch) {
    let title = text;

    // Remove time patterns
    title = title.replace(/in\s+\d+\s+(hour|minute|day)s?/gi, '');
    title = title.replace(/(?:at|@)\s*\d{1,2}:?\d{2}\s*(am|pm)?/gi, '');
    title = title.replace(/tonight|today evening|this evening|tomorrow|next day/gi, '');
    title = title.replace(/\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/gi, '');

    // Clean up extra whitespace
    title = title.replace(/\s+/g, ' ').trim();

    return title || 'Reminder';
  }

  /**
   * Calculate actual date/time from parsed values
   * All times are interpreted in Israel timezone, then stored as UTC ISO string.
   */
  calculateDateTime(time, dateStr, relative) {
    const now = nowInIsrael();
    let targetDate = new Date(now);

    // If relative time (e.g., "in 1 hour" / "בעוד שעה")
    if (relative) {
      const { value, unit } = relative;
      switch (unit.toLowerCase()) {
        case 'minute':
          targetDate.setMinutes(targetDate.getMinutes() + value);
          break;
        case 'hour':
          targetDate.setHours(targetDate.getHours() + value);
          break;
        case 'day':
          targetDate.setDate(targetDate.getDate() + value);
          break;
      }
      // Convert back to real UTC
      return this.#israelToUTC(targetDate);
    }

    // Handle day-based dates
    if (dateStr === 'today') {
      targetDate = new Date(now);
    } else if (dateStr === 'tomorrow') {
      targetDate = new Date(now);
      targetDate.setDate(targetDate.getDate() + 1);
    } else if (dateStr === 'day_after_tomorrow') {
      targetDate = new Date(now);
      targetDate.setDate(targetDate.getDate() + 2);
    } else if (dateStr) {
      // Handle day of week
      const dayMap = {
        monday: 1, tuesday: 2, wednesday: 3, thursday: 4,
        friday: 5, saturday: 6, sunday: 0
      };

      const targetDayNum = dayMap[dateStr.toLowerCase()];
      if (targetDayNum !== undefined) {
        const currentDayNum = now.getDay();
        let daysAhead = targetDayNum - currentDayNum;
        if (daysAhead <= 0) daysAhead += 7;
        targetDate = new Date(now);
        targetDate.setDate(targetDate.getDate() + daysAhead);
      }
    }

    // Set the time
    const [hours, minutes] = time.split(':').map(Number);
    targetDate.setHours(hours, minutes, 0, 0);

    // Convert Israel local time to UTC
    return this.#israelToUTC(targetDate);
  }

  /**
   * Convert a Date that represents Israel local time to actual UTC Date.
   */
  #israelToUTC(israelDate) {
    const y = israelDate.getFullYear();
    const mo = israelDate.getMonth();
    const d = israelDate.getDate();
    const h = israelDate.getHours();
    const mi = israelDate.getMinutes();

    // Create a UTC date with the same clock values
    const probe = new Date(Date.UTC(y, mo, d, h, mi, 0));

    // Find what Israel shows at that UTC instant using formatToParts
    const parts = new Intl.DateTimeFormat('en-GB', {
      timeZone: TIMEZONE,
      hour: '2-digit', minute: '2-digit', day: '2-digit',
      month: '2-digit', year: 'numeric', hour12: false,
    }).formatToParts(probe);

    const get = type => parseInt(parts.find(p => p.type === type).value);
    const israelH = get('hour');
    const israelD = get('day');

    // Offset in hours (handles day boundary: if Israel day > probe day, add 24)
    let offsetH = israelH - h;
    if (israelD > d) offsetH += 24;
    else if (israelD < d) offsetH -= 24;

    // Subtract offset: Israel local - offset = UTC
    return new Date(probe.getTime() - offsetH * 3600000);
  }
}

export default NLPParser;
