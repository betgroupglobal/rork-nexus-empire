import { useState } from 'react';
import { trpc } from './utils/trpc';
import { format } from 'date-fns';
import { 
  LayoutDashboard, 
  Users, 
  MessageSquare, 
  Mail, 
  BellRing, 
  Phone 
} from 'lucide-react';

export default function Dashboard() {
  const [activeTab, setActiveTab] = useState('warroom');

  // TRPC Queries
  const { data: dashboard, isLoading: isDashboardLoading } = trpc.entities.dashboard.useQuery();
  const { data: alerts } = trpc.alerts.list.useQuery();
  const { data: subjects } = trpc.entities.list.useQuery();

  const tabs = [
    { id: 'warroom', label: 'War Room', icon: LayoutDashboard },
    { id: 'subjects', label: 'Subjects', icon: Users },
    { id: 'comms', label: 'Comms', icon: MessageSquare },
    { id: 'email', label: 'Email', icon: Mail },
    { id: 'alerts', label: 'Alerts', icon: BellRing },
    { id: 'crazytel', label: 'CrazyTel', icon: Phone },
  ];

  return (
    <div className="flex h-screen bg-slate-50 text-slate-900 font-sans">
      {/* Sidebar */}
      <aside className="w-64 bg-white border-r border-slate-200 p-6 flex flex-col gap-8 shadow-sm z-10">
        <div>
          <h1 className="text-xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-blue-600 to-indigo-600">
            Nexus Empire
          </h1>
          <p className="text-xs text-slate-500 mt-1 uppercase tracking-wider font-semibold">
            Command Center
          </p>
        </div>

        <nav className="flex flex-col gap-2">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-semibold transition-all duration-200 ${
                  isActive 
                    ? 'bg-blue-50 text-blue-700 border border-blue-100 shadow-sm' 
                    : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
                }`}
              >
                <Icon size={18} className={isActive ? 'text-blue-600' : 'text-slate-400'} />
                {tab.label}
              </button>
            );
          })}
        </nav>
      </aside>

      {/* Main Content */}
      <main className="flex-1 overflow-y-auto p-8">
        <header className="flex justify-between items-end mb-8">
          <div>
            <h2 className="text-3xl font-bold tracking-tight text-slate-800">
              {tabs.find(t => t.id === activeTab)?.label}
            </h2>
          </div>
          <div className="flex gap-3">
            <div className="px-4 py-1.5 rounded-full bg-emerald-50 text-emerald-700 text-xs font-bold border border-emerald-200 shadow-sm">
              System Online
            </div>
          </div>
        </header>

        {isDashboardLoading ? (
          <div className="animate-pulse flex gap-4">
            <div className="h-32 bg-slate-200 rounded-2xl w-1/3"></div>
            <div className="h-32 bg-slate-200 rounded-2xl w-1/3"></div>
            <div className="h-32 bg-slate-200 rounded-2xl w-1/3"></div>
          </div>
        ) : (
          <>
            {activeTab === 'warroom' && (
              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
                  <p className="text-xs font-bold text-slate-400 uppercase tracking-widest mb-1">Total Firepower</p>
                  <p className="text-4xl font-black text-slate-800 tracking-tighter">
                    ${dashboard?.totalFirepower?.toLocaleString()}
                  </p>
                </div>
                <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
                  <p className="text-xs font-bold text-slate-400 uppercase tracking-widest mb-1">Active Subjects</p>
                  <p className="text-4xl font-black text-slate-800 tracking-tighter">
                    {dashboard?.activeCount} <span className="text-lg text-slate-400 font-medium">/ {dashboard?.totalCount}</span>
                  </p>
                </div>
                <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
                  <p className="text-xs font-bold text-slate-400 uppercase tracking-widest mb-1">Urgent Alerts</p>
                  <p className="text-4xl font-black text-red-600 tracking-tighter">
                    {dashboard?.urgentCount}
                  </p>
                </div>
              </div>
            )}

            {activeTab === 'subjects' && (
              <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
                <table className="w-full text-left text-sm">
                  <thead className="bg-slate-50 border-b border-slate-200 text-slate-500 uppercase text-xs font-bold tracking-wider">
                    <tr>
                      <th className="px-6 py-4">Name</th>
                      <th className="px-6 py-4">Type</th>
                      <th className="px-6 py-4">Status</th>
                      <th className="px-6 py-4">Limit</th>
                      <th className="px-6 py-4">Score</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {subjects?.map(sub => (
                      <tr key={sub.id} className="hover:bg-slate-50 transition-colors">
                        <td className="px-6 py-4 font-semibold text-slate-800">{sub.name}</td>
                        <td className="px-6 py-4">{sub.type}</td>
                        <td className="px-6 py-4">
                          <span className="px-3 py-1 rounded-full bg-slate-100 text-slate-600 text-xs font-bold">
                            {sub.status}
                          </span>
                        </td>
                        <td className="px-6 py-4">${sub.creditLimit.toLocaleString()}</td>
                        <td className="px-6 py-4 font-mono">{sub.healthScore}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            
            {activeTab === 'alerts' && (
              <div className="flex flex-col gap-4">
                {alerts?.map(alert => (
                  <div key={alert.id} className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex items-start gap-4">
                    <div className={`p-2 rounded-full ${alert.priority === 'Critical' ? 'bg-red-100 text-red-600' : 'bg-blue-100 text-blue-600'}`}>
                      <BellRing size={20} />
                    </div>
                    <div>
                      <h4 className="font-bold text-slate-800">{alert.title}</h4>
                      <p className="text-sm text-slate-500 mt-1">{alert.message}</p>
                      <p className="text-xs text-slate-400 mt-2">{format(new Date(alert.timestamp), 'PPp')}</p>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </>
        )}
      </main>
    </div>
  );
}
