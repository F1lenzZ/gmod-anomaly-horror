Project: Garry's Mod addon (Lua)

DO NOT:
- Do not generate the full mod unless explicitly asked.
- Do not add gameplay logic unless requested.
- Do not change folder structure without instruction.

DO:
- Keep all addon code under: addon/anomaly_horror/lua/
- Use namespace/table: AH = AH or {}
- Separate code into client / server / shared.
- Ensure it works on any map (gm_construct is priority for testing).
- Prefer small incremental changes and clear commits.

Repo layout:
- Entry: addon/anomaly_horror/lua/autorun/anomaly_horror_init.lua
- Core: addon/anomaly_horror/lua/anomaly_horror/{shared,server,client}/
