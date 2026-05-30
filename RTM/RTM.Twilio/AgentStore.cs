using RTM.Types;
using System.Collections.Concurrent;

public class AgentStore
{
    private readonly ConcurrentDictionary<string, Agent> _byId = new();
    private readonly ConcurrentDictionary<string, Agent> _byName =
        new(StringComparer.OrdinalIgnoreCase);

    public bool TryAdd(Agent agent)
    {
        // סדר חשוב: מונע חצי־מצב
        if (!_byId.TryAdd(agent.WorkerSid, agent))
            return false;

        if (!_byName.TryAdd(agent.UserId, agent))
        {
            _byId.TryRemove(agent.WorkerSid, out _);
            return false;
        }

        return true;
    }

    public bool TryRemoveById(string id)
    {
        if (!_byId.TryRemove(id, out var agent))
            return false;

        _byName.TryRemove(agent.UserId, out _);
        return true;
    }

    public List<Agent> getList()
    {
        return _byName.Values.ToList();
    }

    public Agent? GetById(string id)
        => _byId.TryGetValue(id, out var a) ? a : null;

    public Agent? GetByName(string name)
        => _byName.TryGetValue(name, out var a) ? a : null;
}
