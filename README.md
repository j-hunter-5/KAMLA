# RED THREAD ARCHIVE

Static KAMLA transmedia website with:
- Formspree-backed `JOIN THE SEARCH` submissions
- Supabase email/password researcher accounts
- live database-backed forum threads and replies
- preserved fake 2004 archive threads

## One-time Supabase setup
1. Open Supabase -> SQL Editor -> New query.
2. Paste the contents of `supabase_setup.sql`.
3. Run it once.
4. In Supabase -> Authentication -> URL Configuration, set **Site URL** to the public URL of this website. Add that URL to Redirect URLs too.

## Deploy
Upload `index.html` to the root of the GitHub Pages repository. The Supabase publishable key and Formspree form endpoint in browser code are public client identifiers; never put a Supabase secret/service-role key in this repository.
