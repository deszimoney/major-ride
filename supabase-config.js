window.MRCO_SUPABASE = {
  url: 'https://vxqzzirmnbewpweszvev.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ4cXp6aXJtbmJld3B3ZXN6dmV2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0MTIxNjYsImV4cCI6MjEwNDk4ODE2Nn0.ORC33tY4tOMqCW0kKAm_Cy0RS4oED8cjB8BruGoxfi4'
};

window.MRCO_SUPABASE_READY = Boolean(
  window.MRCO_SUPABASE &&
  window.MRCO_SUPABASE.url &&
  window.MRCO_SUPABASE.url.includes('supabase.co') &&
  window.MRCO_SUPABASE.anonKey &&
  !window.MRCO_SUPABASE.anonKey.includes('YOUR_')
);

window.MRCO_SOCIAL_PROVIDERS = {
  google: true,
  apple: false
};
