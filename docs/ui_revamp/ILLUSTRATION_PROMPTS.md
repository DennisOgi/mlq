# MLQ Illustration Prompt Pack (lean)

**11 images to generate, plus 3 optional.** Everything else in the revamp uses art we already have or is drawn in code.

Goes with [`UI_REVAMP_PLAN.md`](./UI_REVAMP_PLAN.md).

---

## 0. What we don't generate, and why

| Need | Covered by |
|---|---|
| Questor (headers, empty states, floating button, Wallet, chat) | The **existing poses** in `assets/images/questor*.png`: waving, presenting, hands on hips, thinking and more. AI tools won't reproduce him faithfully, so we don't ask them to. |
| Screen headers | Plum-to-violet gradient drawn in code + an existing Questor pose on the right |
| Challenge art, achievements, level-up, Victory Wall cards | The **38 existing badges** in `assets/images/badges/` on a gradient card |
| Wallet and rewards | Existing `coin.jpeg`, `ui_trial_gift.png` and `ui_sparkles.png` + Questor presenting pose |
| Library subjects, Questor quick-starts, format filters | Material Symbols Rounded icons in lilac tiles |
| Lesson slides | The course's topic cover on the first slide; text-led slides after that |
| Empty and offline states | Questor thinking or resting pose + one line of copy |

If a screen still feels bare once it's built, we add art then, for that one spot.

---

## 1. How to prompt

Build each prompt as **STYLE BLOCK + SCENE + FORMAT**, and add the **NEGATIVE** prompt if your tool supports one.

1. Generate **T1 (Leadership)** first. When you're happy with it, attach it as the **style reference** for every other image (ChatGPT/GPT-Image: attach it; Midjourney: `--sref`; Ideogram/Leonardo: style reference).
2. Each cover shows **one student** (two at most). They don't need to be the same person across images. The style and palette are what make the set consistent, which is much easier for AI to hold than a recurring character.
3. **No text in images**: books, boards, signs and screens stay blank or use simple symbols.
4. Deliver **WebP, 1600×1200, under 250 KB**, named exactly as listed, into `assets/images/ui/covers/`.

### Style block

```
Storybook digital illustration for a youth leadership app. Clean thin dark-brown ink outlines, soft cel shading with gentle gradients, warm golden-hour light, rounded friendly shapes. Nigerian secondary-school students aged 11–16, natural proportions, slightly stylised (not chibi, not babyish), expressive faces, natural hair textures, modern everyday clothes. Palette dominated by deep plum #40003D, royal violet #652D6D, soft lilac #F3EAF6 and warm gold #D7C16E with cream #FFF9F0 highlights; small coral or sky-blue accents are fine; greenery only as minor background detail. Where it fits, a distant mountain peak with a small plum flag bearing a gold crown. Uncluttered, one clear focal point. No text, letters, numbers, logos or watermarks anywhere.
```

### Format line

```
4:3 composition, 1600x1200. Keep the subject inside the central 60% so the image can be cropped to 16:9 and 1:1 without losing it.
```

### Negative prompt

```
text, words, letters, numbers, labels, logo, watermark, signature, UI, photorealistic, 3D plastic render, glossy CGI, anime, chibi, toddler proportions, extra fingers, deformed hands, cropped heads, cluttered background, neon colours, dominant green, dark or scary mood
```

---

## 2. The 11 images

### Topic covers (8)

Every daily mini course is tagged with a topic. These 8 covers group all the topics we actually generate (counts from `global_daily_courses`).

| # | File | Covers topics | Scene |
|---|---|---|---|
| T1 | `leadership.webp` | Leadership, Influence, Vision (~125 courses) | A teenage boy with glasses leads a small group of classmates up a winding path toward the crown-flag mountain, pointing ahead with an encouraging smile while they follow, energised. |
| T2 | `communication.webp` | Communication, Teamwork, Listening, Conflict Resolution, Respect, Inclusion (~130) | Two students talking face to face on school steps, one listening closely and nodding, two empty rounded speech-bubble shapes floating softly above them. |
| T3 | `mindset.webp` | Mindset, Motivation, Confidence, Personal Growth, Purpose (~185) | A girl with box braids standing tall on a hilltop at sunrise, shoulders back, a small glowing lightbulb-shaped plant sprouting beside her. |
| T4 | `emotions.webp` | Emotional Intelligence, Empathy, Gratitude, Stress, Calm (~75) | A girl in a violet hijab sitting on a bench beside a sad classmate, hand on their shoulder, a soft heart-shaped glow between them. |
| T5 | `resilience.webp` | Resilience, Bouncing Back, Adaptability, Trying New Things (~60) | A girl on a running track getting back up after a fall, brushing off her knee with a determined smile, finish-line flag in the distance. |
| T6 | `planning.webp` | Goal Setting, Time Management, Productivity, Self-Discipline, Habits, New Year / Holiday / Back to School (~215) | A boy in a plum hoodie at a tidy desk arranging floating clock and calendar blocks into a neat stack, a small plum flag planted on the desk. |
| T7 | `thinking.webp` | Decision Making, Problem Solving, Creativity, Critical Thinking, Honesty (~110) | A boy at a fork in a path with two blank wooden signposts, hand on chin, one path leading toward the crown-flag mountain. |
| T8 | `health.webp` | All health topics: water, food, sleep, handwashing, movement, posture (~110) | A girl jogging along a tree-lined path at sunrise holding a violet water bottle, energetic and happy. |

Anything that doesn't match uses a code-drawn fallback (gradient + Questor pose), so there's no ninth image.

### Goal category covers (3)

Shown on the main goal card on Home and Goals. Save to `assets/images/ui/covers/`.

| # | File | Scene |
|---|---|---|
| G1 | `goal_academic.webp` | A girl at a study desk holding up a paper with a big gold star sticker, a stack of books and a desk lamp, proud smile. |
| G2 | `goal_social.webp` | Three friends laughing together on school steps, one with an arm around another's shoulder, warm afternoon light. |
| G3 | `goal_health.webp` | *Reuse T8* if you're short on time; otherwise: a boy stretching in a park in the morning, a water bottle and sneakers beside him. |

---

## 3. Optional (only if the screens feel bare once built)

| # | File | Format | Scene |
|---|---|---|---|
| O1 | `wallet_chest.webp` | 21:9, 1680×720, subject on the right | An open treasure chest overflowing with gold coins with a crown emblem on a twilight hill, left side soft plum for text. No people. |
| O2 | `all_done.webp` | 4:3 | Four students celebrating on a mountain summit beside the crown flag, arms raised, gold confetti at sunset (Today's Quest when everything is done). |
| O3 | `school_banner.webp` | 21:9, 1680×720, subject on the right | A welcoming Nigerian secondary school building with a gate and a flagpole flying the plum crown flag at dusk, left side soft plum for text (School library header). |

---

## 4. Topic → cover mapping (for the developer)

Lower-case the topic and check the rows in order. The first match wins, and anything unmatched uses the code fallback.

| Order | If topic contains | Cover |
|---|---|---|
| 1 | `handwash`, `teeth`, `smile`, `water`, `thirst`, `soda`, `rainbow`, `snack`, `breakfast`, `protein`, `sugar`, `sleep`, `rest`, `screen`, `move`, `posture`, `health` | health |
| 2 | `lead`, `influence`, `vision` | leadership |
| 3 | `goal`, `time`, `productiv`, `focus`, `concentrat`, `discipline`, `habit`, `accountab`, `organi`, `responsib`, `new year`, `holiday`, `back to school`, `fresh start` | planning |
| 4 | `communicat`, `listen`, `speak`, `voice`, `team`, `collab`, `conflict`, `respect`, `inclusion`, `friend`, `boundar` | communication |
| 5 | `emotion`, `empathy`, `gratitude`, `apprecia`, `stress`, `calm`, `breathe`, `kind` | emotions |
| 6 | `resilien`, `bounc`, `adapt`, `new things`, `peer pressure` | resilience |
| 7 | `decision`, `problem`, `creativ`, `critical`, `choice`, `honest`, `integrity` | thinking |
| 8 | `mindset`, `motivat`, `confiden`, `growth`, `identity`, `purpose`, `celebrat`, `self-advoca`, `learning` | mindset |

Health is checked first so that, for example, "Faith and Health" and "Sleep and Energy" don't fall through. Planning comes before communication so that "Holiday Productivity Hacks" goes to planning.

---

## 5. Checklist before handing over

- [ ] No readable text, letters or numbers (zoom in on books and signs)
- [ ] All 11 share the same line weight, shading and palette (put them side by side)
- [ ] Plum, violet and gold dominate; no bright green, pink or blue scenes
- [ ] Hands and faces look right
- [ ] Subject sits in the central 60%
- [ ] WebP, 1600×1200, under 250 KB, correct filenames
