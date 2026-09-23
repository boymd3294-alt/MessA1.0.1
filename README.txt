MESSA – teljes Supabase MVP

1. Nyisd meg az index.html-t.
2. A script elején töltsd ki:
   SUPABASE_URL = 'https://....supabase.co'
   SUPABASE_KEY = 'sb_publishable_...' vagy a régi anon public kulcs.
3. Supabase → SQL Editor → New query → másold be a schema.sql teljes tartalmát → Run.
4. Authentication → Providers → Email legyen engedélyezve.
5. Ha e-mail megerősítés be van kapcsolva, regisztráció után a felhasználó csak megerősítő e-mail után tud belépni.
6. Az index.html statikus, nem kell Python/Flask.

A csomag nem tartalmaz tesztfelhasználót, tesztposztot vagy kamu üzenetet.
Minden tartalom csak valódi, bejelentkezett felhasználótól kerül az adatbázisba.

Funkciók:
- valódi regisztráció és bejelentkezés
- profil és profilkép
- posztok és képek/fájlok
- like és komment
- közösségek
- privát üzenetek
- értesítések tábla
- követés adatmodell
- Supabase RLS
- Realtime üzenetek és posztfrissítés

Biztonság: service_role/secret kulcsot SOHA ne tegyél az index.html-be.
A böngészőben csak a publikus Project URL + Publishable/anon public kulcs használható.
