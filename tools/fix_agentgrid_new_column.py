#!/usr/bin/env python3
"""Add RTM /LoadData trigger after saving AgentGrid/QueueGrid columns."""
import os

path = r"D:\Claude\Projects\RTM View Shell\src\CcDashboard.Web\Components\Dashboard\ScreenEditorPage.razor"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# 1. Add NotifyRtmLoadDataAsync call after AgentGrid save (after updating column DbColumnIds)
old_agent_block = '''                // Update column DbColumnIds from RTS result
                foreach (var (title, dbColumnId) in rtsResult.SavedColumns)
                {
                    var colDef = ConfigAgentColumnDefs.FirstOrDefault(c => c.Name == title);
                    if (colDef != null)
                    {
                        colDef.DbColumnId = dbColumnId;
                    }
                }
            }
            catch (Exception ex)
            {
                Error = $"RTS save failed: {ex.Message}";'''

new_agent_block = '''                // Update column DbColumnIds from RTS result
                foreach (var (title, dbColumnId) in rtsResult.SavedColumns)
                {
                    var colDef = ConfigAgentColumnDefs.FirstOrDefault(c => c.Name == title);
                    if (colDef != null)
                    {
                        colDef.DbColumnId = dbColumnId;
                    }
                }

                // Notify RTM Service to reload metrics so new columns are included in updateUserGrid
                _ = NotifyRtmLoadDataAsync();
            }
            catch (Exception ex)
            {
                Error = $"RTS save failed: {ex.Message}";'''

text = text.replace(old_agent_block, new_agent_block)

# 2. Add NotifyRtmLoadDataAsync call after QueueGrid save (after updating SavedCellIds)
old_queue_block = '''                        if (rtsResult.SavedCellIds.TryGetValue(localId, out var cellIds))
                        {
                            rowDef.CellIds = cellIds.ToDictionary(kvp => kvp.Key, kvp => (int?)kvp.Value);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Error = $"Queue Grid RTS save failed: {ex.Message}";'''

new_queue_block = '''                        if (rtsResult.SavedCellIds.TryGetValue(localId, out var cellIds))
                        {
                            rowDef.CellIds = cellIds.ToDictionary(kvp => kvp.Key, kvp => (int?)kvp.Value);
                        }
                    }
                }

                // Notify RTM Service to reload metrics so new columns are included in updateGridData
                _ = NotifyRtmLoadDataAsync();
            }
            catch (Exception ex)
            {
                Error = $"Queue Grid RTS save failed: {ex.Message}";'''

text = text.replace(old_queue_block, new_queue_block)

# 3. Add NotifyRtmLoadDataAsync call after ASD Group+State grids save
old_asd_block = '''                _asdStateGridId = stateRtsResult.GridId;

                // Legacy GridId kept null for CC-009 widgets (dual-mode)
                queueGridId = null;
            }
            catch (Exception ex)
            {
                Error = $"Agent State Distribution RTS save failed: {ex.Message}";'''

new_asd_block = '''                _asdStateGridId = stateRtsResult.GridId;

                // Legacy GridId kept null for CC-009 widgets (dual-mode)
                queueGridId = null;

                // Notify RTM Service to reload metrics so new columns are included
                _ = NotifyRtmLoadDataAsync();
            }
            catch (Exception ex)
            {
                Error = $"Agent State Distribution RTS save failed: {ex.Message}";'''

text = text.replace(old_asd_block, new_asd_block)

# 4. Add the NotifyRtmLoadDataAsync helper method after SaveLayout method
# Find a suitable location - after SaveLayout method
old_save_layout_end = '''    private async Task SaveLayout()
    {
        if (Dashboard is null) return;
        Error = null;

        try
        {
            Dashboard.LayoutJson = GetUpdatedLayoutJson();
            await Mediator.Send(new UpdateDashboardCommand(Dashboard.Id, Dashboard.Name, Dashboard.Description, Dashboard.LayoutJson, Dashboard.IsPublic), _cts.Token);
        }
        catch (Exception ex)
        {
            Error = ex.Message;
        }
    }'''

new_save_layout_end = '''    private async Task SaveLayout()
    {
        if (Dashboard is null) return;
        Error = null;

        try
        {
            Dashboard.LayoutJson = GetUpdatedLayoutJson();
            await Mediator.Send(new UpdateDashboardCommand(Dashboard.Id, Dashboard.Name, Dashboard.Description, Dashboard.LayoutJson, Dashboard.IsPublic), _cts.Token);
        }
        catch (Exception ex)
        {
            Error = ex.Message;
        }
    }

    private async Task NotifyRtmLoadDataAsync()
    {
        try
        {
            if (Dashboard?.TenantId == null) return;

            var settings = await Mediator.Send(new GetTenantSettingsQuery(Dashboard.TenantId), _cts.Token);
            if (string.IsNullOrEmpty(settings?.SignalRConnectionUrl)) return;

            // Build base URL from SignalR URL (strip /signalr suffix if present)
            var baseUrl = settings.SignalRConnectionUrl.TrimEnd('/');
            if (baseUrl.EndsWith("/signalr", StringComparison.OrdinalIgnoreCase))
                baseUrl = baseUrl[..^8];

            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
            await http.GetAsync($"{baseUrl}/LoadData");
            Logger.LogInformation("ScreenEditorPage: RTM LoadData triggered after column save");
        }
        catch (Exception ex)
        {
            Logger.LogWarning(ex, "ScreenEditorPage: RTM LoadData notification failed (non-critical)");
        }
    }'''

text = text.replace(old_save_layout_end, new_save_layout_end)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
    f.flush()
    os.fsync(f.fileno())

print(f"Fixed ScreenEditorPage.razor ({len(text.splitlines())} lines)")
