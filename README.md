# JamByrd

Record songs in layers (4 to 16 tracks), save them online automatically, and share a link so friends can add their own parts. Includes a click or drum groove to play along to, and Auto drums that follow what you've recorded.

Open it at https://ngoose7-stack.github.io/JamByrd/ and, on iPhone, tap Share → Add to Home Screen.

Backend: Supabase (see `supabase-setup.sql`). The key in `index.html` is a publishable key, made to be public; the database only allows access through the jb_* functions.

Drum sounds: Versilian Community Sample Library (CC0, https://github.com/sgossner/VCSL), packed into `kit.bin` by `tools/build_kit.py`.
