# codekeeper-plugin

פלאגין Claude שמחבר את CodeKeeper כזיכרון מתמשך.

שני חלקים, והם עצמאיים זה מזה:

1. **הוראות סוכן שנטענות בפתיחת סשן** — hook מסוג `SessionStart` מושך טקסט מ‑CodeKeeper ומדפיס אותו. מה שהוא מדפיס נכנס לקונטקסט של הסשן לפני ההודעה הראשונה.
2. **שרת ה‑MCP הקיים** — 18 הכלים של CodeKeeper, נטענים יחד עם הפלאגין.

## מבנה

```
.claude-plugin/marketplace.json      מגדיר את המרקטפלייס האישי
codekeeper-memory/
  .claude-plugin/plugin.json         מטא-דאטה של הפלאגין
  .mcp.json                          מצביע על שרת ה-MCP של CodeKeeper
  hooks/hooks.json                   רושם את ה-SessionStart hook
  hooks/session_start.sh             מושך ומדפיס את הפריימר
```

## מה צריך לבנות בצד השרת

**אנדפוינט אחד:**

```
GET /api/agent/primer
Authorization: Bearer <PAT>
Accept: text/plain
→ 200, גוף הטקסט של ההוראות
```

מחזיר טקסט גולמי, לא JSON. ה‑hook מדפיס אותו כמו שהוא, ולכן כל מה שיוצא משם נקרא על ידי הסוכן verbatim.

**ושדה טקסט אחד** בהגדרות CodeKeeper — "הוראות לסוכן" — שהאנדפוינט מגיש. זה מה שנערך מהדפדפן.

מומלץ שהאנדפוינט יחזיר גם, בסוף הטקסט, שורה או שתיים על מה שהשתנה לאחרונה — למשל שמות שלושת הקבצים האחרונים שנשמרו. זה מה שהופך את הפריימר מקבוע לחי.

## משתני סביבה

| משתנה | חובה | ברירת מחדל |
|---|---|---|
| `CODEKEEPER_PAT` | כן | — |
| `CODEKEEPER_PRIMER_URL` | לא | `https://code-keeper-mcp.onrender.com/api/agent/primer` |
| `CODEKEEPER_MCP_URL` | לא | `https://code-keeper-webapp.onrender.com/mcp` |

בלי `CODEKEEPER_PAT` ה‑hook יוצא בשקט ולא מדפיס כלום. הסשן נפתח רגיל.

> ⚠️ **האנדפוינט `/api/agent/primer` חי על שירות ה-MCP**, לא על הוובאפ. הצבעה ל-`https://code-keeper-webapp.onrender.com/api/agent/primer` תחזיר `404` — הוובאפ לא מכיר בנתיב הזה. השתמשו ב-MCP host: `https://code-keeper-mcp.onrender.com/api/agent/primer`.

## התקנה

```
/plugin marketplace add amirbiron/codekeeper-plugin
/plugin install codekeeper-memory@amirbiron
```

## בדיקה שזה עובד

```sh
CODEKEEPER_PAT=... sh codekeeper-memory/hooks/session_start.sh
```

אמור להדפיס את טקסט ההוראות. אם לא מודפס כלום — או שאין טוקן, או שהאנדפוינט לא קיים עדיין, או שהשרת ישן. ה‑hook לא מבחין ביניהם בכוונה; הוא לא אמור להקשות על פתיחת סשן בשום מצב.

## רישיון

MIT.

מבנה הפלאגין (סידור התיקיות, `hooks.json`, `plugin.json`) הותאם מ‑[Vertiso/memory-claude](https://github.com/Vertiso/memory-claude), MIT, ‏© 2026 Vertiso Corporation.

הבדל מהותי אחד: אצלם ה‑hook מריץ CLI בשם `vmem` ואם הוא לא מותקן — לא קורה כלום, והטעינה בפועל נשענת על כך שהמודל יחליט לקרוא לכלי MCP. כאן ה‑hook מושך ומדפיס בעצמו, ולכן הטעינה לא תלויה בשיפוט של המודל ולא דורשת התקנה של שום בינארי.
