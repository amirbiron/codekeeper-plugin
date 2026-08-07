# codekeeper-plugin

פלאגין Claude שמחבר את CodeKeeper כזיכרון מתמשך.

הפלאגין עושה **דבר אחד**: hook מסוג `SessionStart` מושך טקסט מ‑CodeKeeper ומדפיס אותו. מה שהוא מדפיס נכנס לקונטקסט של הסשן לפני ההודעה הראשונה.

**את שרת ה‑MCP מוסיפים בנפרד**, כ‑Connector רגיל — ראו למטה. הפלאגין לא אורז אותו, ובכוונה.

## מבנה

```
.claude-plugin/marketplace.json      מגדיר את המרקטפלייס האישי
codekeeper-memory/
  .claude-plugin/plugin.json         מטא-דאטה של הפלאגין
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
| `CODEKEEPER_PRIMER_URL` | כן | — |

**ל‑`CODEKEEPER_PRIMER_URL` אין ברירת מחדל בכוונה.** הפריימר מוגש על ידי שירות ה‑MCP, שהוא שירות Render נפרד מה‑webapp. ברירת מחדל שנראית סבירה ומצביעה על ההוסט הלא נכון תחזיר 404 לנצח, וזה בדיוק סוג התקלה שהמימוש הזה נועד למנוע.

## מה ההוק מדפיס, ולאן

| מצב | stdout | stderr |
|---|---|---|
| 200 עם גוף | הפריימר | — |
| 204 (אין הוראות) | — | — |
| 200 עם גוף ריק | — | הערה |
| 401 / 403 | — | "בדוק את CODEKEEPER_PAT" |
| 404 | — | "בדוק שה‑URL מצביע על שירות ה‑MCP" |
| 5xx / timeout | — | הערה |
| חסר PAT או URL | — | הערה |

ההפרדה עקרונית: **stdout הוא הקשר שהסוכן קורא, stderr הוא הודעה לאדם.** אסור ששום דבר מלבד הפריימר יגיע ל‑stdout, אחרת הסוכן יקרא טקסט שגיאה כאילו היה הוראה.

שתיקה שמורה למקרה אחד בלבד — **204**, כלומר אין הוראות מוגדרות. זה מצב ריק לגיטימי ולא תקלה. כל כשל אחר אומר שורה אחת. הוק ששותק תמיד אינו ניתן להבחנה מהוק שעובד, וכך URL שגוי שורד חודשים בלי שאיש ישים לב.

בכל המצבים ה‑hook מחזיר `exit 0` והסשן נפתח כרגיל.

## התקנה

ב‑Claude Code בטרמינל:

```
/plugin marketplace add amirbiron/codekeeper-plugin
/plugin install codekeeper-memory@amirbiron
```

ב‑Claude Code בדפדפן (`claude.ai/code`) הפקודה `/plugin` אינה קיימת — מתקינים דרך
**Settings › Plugins › Directory**.

## שרת ה‑MCP — למה הוא לא כאן

הפלאגין נושא רק את ה‑hook. את שרת ה‑MCP מוסיפים ידנית כ‑Connector:

```
Settings › Connectors › Add custom connector
  URL:  https://codekeeper-mcp.onrender.com/mcp
```

**זו לא עצלות, זו הימנעות מבאג.** הפלאגין נשא בעבר `.mcp.json` עם
`"url": "${CODEKEEPER_MCP_URL:-...}"` ו‑`"Authorization": "Bearer ${CODEKEEPER_PAT}"`.
הרחבת `${VAR}` היא פיצ'ר של Claude Code CLI; ממשק הפלאגינים בדפדפן לוקח את
המחרוזת כלשונה. ה‑URL נפסל בוולידציה (`URL must start with 'https'`) — וזה
דווקא המזל, כי הכותרת הייתה נשלחת מילולית ומחזירה 401 בלי הסבר.

והתיקון שנראה מתבקש — לקודד את הטוקן קשיח בקובץ — היה שם סוד אמיתי בריפו ציבורי.
Connector שמוגדר ידנית שומר את הטוקן בהגדרות המקומיות, במקום שאליו הוא שייך.

## בדיקה שזה עובד

```sh
CODEKEEPER_PAT=... \
CODEKEEPER_PRIMER_URL=https://<mcp-host>/api/agent/primer \
  sh codekeeper-memory/hooks/session_start.sh
```

הפריימר יודפס ל‑stdout. אם משהו לא תקין, תראה שורת אבחון אחת ב‑stderr שאומרת בדיוק מה — 401 מפנה לטוקן, 404 מפנה ל‑URL, וכן הלאה. שקט מוחלט פירושו דבר אחד בלבד: 204, כלומר שדה ההוראות ריק.

להפריד בין השניים:

```sh
... sh codekeeper-memory/hooks/session_start.sh 2>/dev/null   # רק הפריימר
... sh codekeeper-memory/hooks/session_start.sh >/dev/null    # רק האבחון
```

## רישיון

MIT.

מבנה הפלאגין (סידור התיקיות, `hooks.json`, `plugin.json`) הותאם מ‑[Vertiso/memory-claude](https://github.com/Vertiso/memory-claude), MIT, ‏© 2026 Vertiso Corporation.

הבדל מהותי אחד: אצלם ה‑hook מריץ CLI בשם `vmem` ואם הוא לא מותקן — לא קורה כלום, והטעינה בפועל נשענת על כך שהמודל יחליט לקרוא לכלי MCP. כאן ה‑hook מושך ומדפיס בעצמו, ולכן הטעינה לא תלויה בשיפוט של המודל ולא דורשת התקנה של שום בינארי.
