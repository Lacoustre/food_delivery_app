import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  collection,
  onSnapshot,
  query,
  orderBy,
  where,
  doc,
  updateDoc,
  serverTimestamp,
  Timestamp,
  limit,
  startAfter,
  getCountFromServer,
  QueryConstraint,
  DocumentSnapshot,
} from 'firebase/firestore';
import { getAuth } from 'firebase/auth';
import { db } from '../firebase';
import {
  Car, Phone, Mail, CreditCard, CheckCircle, XCircle, Clock, Users, Search
} from 'lucide-react';

type Approval = 'pending' | 'approved' | 'rejected';

interface Driver {
  id: string;
  fullName: string;
  email: string;
  phone: string;
  licenseNumber?: string;
  vehicleType?: string;
  approvalStatus: Approval;
  createdAt: Date | null;
}

interface FirestoreDriverData {
  fullName?: string;
  name?: string;
  email?: string;
  phone?: string;
  licenseNumber?: string;
  vehicleType?: string;
  approvalStatus?: Approval;
  createdAt?: Timestamp | { toDate?: () => Date };
}

const PAGE_SIZE = 20;

const Drivers: React.FC = () => {
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [loading, setLoading] = useState(true);
  const [permError, setPermError] = useState<string | null>(null);
  const [filter, setFilter] = useState<Approval | 'all'>('all');
  const [qtext, setQtext] = useState('');
  const [busyId, setBusyId] = useState<string | null>(null);

  // pagination
  const [page, setPage] = useState(0);
  const [hasNext, setHasNext] = useState(false);
  const cursors = useRef<DocumentSnapshot[]>([]); // one cursor per page index (startAfter anchor)

  // counts
  const [counts, setCounts] = useState({ total: 0, pending: 0, approved: 0, rejected: 0 });

  // build query constraints whenever filter/page changes
  const qConstraints = useMemo<QueryConstraint[]>(() => {
    const base: QueryConstraint[] = [];
    if (filter !== 'all') base.push(where('approvalStatus', '==', filter));
    base.push(orderBy('createdAt', 'desc'));
    if (page > 0 && cursors.current[page - 1]) {
      base.push(startAfter(cursors.current[page - 1]));
    }
    base.push(limit(PAGE_SIZE + 1)); // fetch one extra to know if next page exists
    return base;
  }, [filter, page]);

  useEffect(() => {
    // whenever filter changes, reset pagination
    setPage(0);
    cursors.current = [];
  }, [filter]);

  useEffect(() => {
    const coll = collection(db, 'drivers');
    const qRef = query(coll, ...qConstraints);

    setLoading(true);
    const unsub = onSnapshot(
      qRef,
      async (snap) => {
        setPermError(null);

        // pagination bookkeeping
        let docs = snap.docs;
        setHasNext(docs.length > PAGE_SIZE);
        if (docs.length > PAGE_SIZE) {
          docs = docs.slice(0, PAGE_SIZE);
        }
        if (docs.length > 0) {
          // store cursor for this page (last doc of this page)
          cursors.current[page] = docs[docs.length - 1];
        }

        const list: Driver[] = docs.map((d) => {
          const data = d.data() as FirestoreDriverData;
          const created = data.createdAt instanceof Timestamp
            ? data.createdAt.toDate()
            : (data.createdAt?.toDate?.() ?? null);

          return {
            id: d.id,
            fullName: (data.fullName ?? data.name ?? '—') as string,
            email: (data.email ?? '—') as string,
            phone: (data.phone ?? '—') as string,
            licenseNumber: (data.licenseNumber ?? '—') as string,
            vehicleType: (data.vehicleType ?? '—') as string,
            approvalStatus: (data.approvalStatus ?? 'pending') as Approval,
            createdAt: created,
          };
        });
        setDrivers(list);
        setLoading(false);

        // refresh counts (best-effort; not real-time)
        try {
          const totalQ = query(coll);
          const pendingQ = query(coll, where('approvalStatus', '==', 'pending'));
          const approvedQ = query(coll, where('approvalStatus', '==', 'approved'));
          const rejectedQ = query(coll, where('approvalStatus', '==', 'rejected'));
          const [t, p, a, r] = await Promise.all([
            getCountFromServer(totalQ),
            getCountFromServer(pendingQ),
            getCountFromServer(approvedQ),
            getCountFromServer(rejectedQ),
          ]);
          setCounts({
            total: t.data().count,
            pending: p.data().count,
            approved: a.data().count,
            rejected: r.data().count,
          });
        } catch {
          // fallback to local counts (page only)
          setCounts({
            total: list.length,
            pending: list.filter(d => d.approvalStatus === 'pending').length,
            approved: list.filter(d => d.approvalStatus === 'approved').length,
            rejected: list.filter(d => d.approvalStatus === 'rejected').length,
          });
        }
      },
      (err) => {
        console.error('drivers error:', err);
        const code = (err as { code?: string })?.code || 'unknown';
        const msg = (err as { message?: string })?.message || '';
        // Try to surface index link if present
        const idxMatch = msg.match(/https:\/\/console\.firebase\.google\.com\/[^\s"]+/);
        if (code === 'failed-precondition' && idxMatch) {
          setPermError(`index-required::${idxMatch[0]}`);
        } else {
          setPermError(code);
        }
        setLoading(false);
      }
    );

    return () => unsub();
  }, [qConstraints, page]);

  // local search after server-side filter (fast + flexible)
  const filtered = useMemo(() => {
    if (!qtext.trim()) return drivers;
    const t = qtext.toLowerCase();
    return drivers.filter((d) =>
      d.fullName.toLowerCase().includes(t) ||
      d.email.toLowerCase().includes(t) ||
      d.phone.toLowerCase().includes(t)
    );
  }, [drivers, qtext]);

  const approveOrReject = useCallback(
    async (driverId: string, status: Extract<Approval, 'approved' | 'rejected'>) => {
      try {
        setBusyId(driverId);
        await updateDoc(doc(db, 'drivers', driverId), {
          approvalStatus: status,
          reviewedAt: serverTimestamp(),
          reviewedBy: getAuth().currentUser?.uid ?? null,
        });
        // onSnapshot will reflect change
      } catch (e) {
        console.error(e);
        alert('Update failed. Check your permissions/rules.');
      } finally {
        setBusyId(null);
      }
    },
    []
  );

  const nextPage = async () => {
    if (!hasNext) return;
    setPage((p) => p + 1);
  };

  const prevPage = () => {
    if (page === 0) return;
    setPage((p) => p - 1);
  };

  if (loading) {
    return (
      <div className="p-8">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-200 rounded w-1/4 mb-6" />
          <div className="bg-white rounded-xl shadow-sm p-6">
            <div className="space-y-4">
              {Array.from({ length: 6 }).map((_, i) => (
                <div key={i} className="h-16 bg-gray-100 rounded-lg" />
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (permError) {
    const isIndex = permError.startsWith('index-required::');
    const link = isIndex ? permError.replace('index-required::', '') : null;
    return (
      <div className="p-8">
        <div className={`rounded-xl p-6 border ${isIndex ? 'bg-amber-50 border-amber-200 text-amber-900' : 'bg-red-50 border-red-200 text-red-800'}`}>
          <p className="font-semibold mb-1">{isIndex ? 'Composite index required' : 'Permission denied'}</p>
          {isIndex ? (
            <p className="text-sm">
              Create the suggested index for this query:{' '}
              <a className="underline" href={link!} target="_blank" rel="noreferrer">Open index creation</a>.
            </p>
          ) : (
            <>
              <p className="text-sm">
                Sign in as an admin (ensure <code>admins/&#123;uid&#125;.role</code> is <code>"admin"</code>).
              </p>
              <p className="text-xs mt-2 opacity-80">Error: {permError}</p>
            </>
          )}
        </div>
      </div>
    );
  }

  const { total, pending, approved, rejected } = counts;

  return (
    <div className="p-8 bg-gray-50 min-h-screen">
      <div className="mb-6 flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 mb-1">Driver Management</h1>
          <p className="text-gray-600">Manage and approve driver applications</p>
        </div>
        <div className="flex gap-2">
          {(['all','pending','approved','rejected'] as const).map((k) => (
            <button
              key={k}
              onClick={() => setFilter(k)}
              className={`px-3 py-1.5 rounded-lg text-sm border ${
                filter === k ? 'bg-orange-600 text-white border-orange-600' : 'bg-white text-gray-700 border-gray-200'
              }`}
            >
              {k[0].toUpperCase() + k.slice(1)}
            </button>
          ))}
        </div>
      </div>

      {/* Top Row */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <StatCard title="Total Drivers" value={total} icon={<Users className="w-6 h-6 text-blue-600" />} bg="bg-blue-100" />
        <StatCard title="Pending" value={pending} icon={<Clock className="w-6 h-6 text-amber-600" />} bg="bg-amber-100" valueClass="text-amber-600" />
        <StatCard title="Approved" value={approved} icon={<CheckCircle className="w-6 h-6 text-green-600" />} bg="bg-green-100" valueClass="text-green-600" />
        <StatCard title="Rejected" value={rejected} icon={<XCircle className="w-6 h-6 text-red-600" />} bg="bg-red-100" valueClass="text-red-600" />
      </div>

      {/* Search */}
      <div className="mb-6">
        <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-3 flex items-center gap-2">
          <Search className="w-5 h-5 text-gray-400" />
          <input
            placeholder="Search by name, email or phone…"
            className="flex-1 outline-none text-sm"
            value={qtext}
            onChange={(e) => setQtext(e.target.value)}
          />
        </div>
      </div>

      {/* List */}
      <div className="grid gap-6">
        {filtered.length === 0 ? (
          <div className="bg-white rounded-xl shadow-sm p-12 text-center">
            <Car className="w-16 h-16 text-gray-300 mx-auto mb-4" />
            <h3 className="text-lg font-medium text-gray-900 mb-2">No drivers {filter !== 'all' ? filter : ''} yet</h3>
            <p className="text-gray-500">New applications will appear here in real time.</p>
          </div>
        ) : (
          filtered.map((driver) => (
            <div key={driver.id} className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 hover:shadow-md transition-shadow">
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="p-2 bg-orange-100 rounded-lg">
                      <Car className="w-5 h-5 text-orange-600" />
                    </div>
                    <div>
                      <h3 className="text-lg font-semibold text-gray-900">{driver.fullName}</h3>
                      <div className="flex flex-wrap items-center gap-4 text-sm text-gray-500 mt-1">
                        <a className="flex items-center gap-1 hover:underline" href={`mailto:${driver.email}`}>
                          <Mail className="w-4 h-4" />
                          {driver.email}
                        </a>
                        <a className="flex items-center gap-1 hover:underline" href={`tel:${driver.phone}`}>
                          <Phone className="w-4 h-4" />
                          {driver.phone}
                        </a>
                      </div>
                    </div>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                    <div className="flex items-center gap-2 text-sm text-gray-600">
                      <CreditCard className="w-4 h-4" />
                      <span className="font-medium">License:</span>
                      <span>{driver.licenseNumber ?? '—'}</span>
                    </div>
                    <div className="flex items-center gap-2 text-sm text-gray-600">
                      <Car className="w-4 h-4" />
                      <span className="font-medium">Vehicle:</span>
                      <span className="capitalize">{driver.vehicleType ?? '—'}</span>
                    </div>
                    <div className="text-sm text-gray-500">
                      Joined:{' '}
                      {driver.createdAt
                        ? new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(driver.createdAt)
                        : '—'}
                    </div>
                  </div>
                </div>

                <div className="flex flex-col items-end gap-3">
                  <span
                    className={`px-3 py-1 text-sm font-medium rounded-full flex items-center gap-1 ${
                      driver.approvalStatus === 'approved'
                        ? 'bg-green-100 text-green-800'
                        : driver.approvalStatus === 'rejected'
                        ? 'bg-red-100 text-red-800'
                        : 'bg-amber-100 text-amber-800'
                    }`}
                  >
                    {driver.approvalStatus === 'approved' && <CheckCircle className="w-4 h-4" />}
                    {driver.approvalStatus === 'rejected' && <XCircle className="w-4 h-4" />}
                    {driver.approvalStatus === 'pending' && <Clock className="w-4 h-4" />}
                    <span className="capitalize">{driver.approvalStatus}</span>
                  </span>

                  {driver.approvalStatus === 'pending' && (
                    <div className="flex gap-2">
                      <button
                        onClick={() => approveOrReject(driver.id, 'approved')}
                        disabled={busyId === driver.id}
                        className={`px-4 py-2 bg-green-600 text-white text-sm font-medium rounded-lg transition-colors flex items-center gap-1 ${
                          busyId === driver.id ? 'opacity-60 cursor-not-allowed' : 'hover:bg-green-700'
                        }`}
                      >
                        <CheckCircle className="w-4 h-4" />
                        {busyId === driver.id ? 'Approving…' : 'Approve'}
                      </button>
                      <button
                        onClick={() => approveOrReject(driver.id, 'rejected')}
                        disabled={busyId === driver.id}
                        className={`px-4 py-2 bg-red-600 text-white text-sm font-medium rounded-lg transition-colors flex items-center gap-1 ${
                          busyId === driver.id ? 'opacity-60 cursor-not-allowed' : 'hover:bg-red-700'
                        }`}
                      >
                        <XCircle className="w-4 h-4" />
                        {busyId === driver.id ? 'Rejecting…' : 'Reject'}
                      </button>
                    </div>
                  )}
                </div>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Pagination */}
      <div className="flex items-center justify-between mt-8">
        <div className="text-sm text-gray-500">
          Page <span className="font-medium">{page + 1}</span>
        </div>
        <div className="flex gap-2">
          <button
            onClick={prevPage}
            disabled={page === 0}
            className={`px-3 py-1.5 rounded-lg text-sm border ${
              page === 0 ? 'bg-gray-100 text-gray-400 border-gray-200' : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
            }`}
          >
            Previous
          </button>
          <button
            onClick={nextPage}
            disabled={!hasNext}
            className={`px-3 py-1.5 rounded-lg text-sm border ${
              !hasNext ? 'bg-gray-100 text-gray-400 border-gray-200' : 'bg-white text-gray-700 border-gray-200 hover:bg-gray-50'
            }`}
          >
            Next
          </button>
        </div>
      </div>
    </div>
  );
};

const StatCard = ({
  title, value, icon, bg, valueClass,
}: { title: string; value: number; icon: React.ReactNode; bg: string; valueClass?: string; }) => (
  <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
    <div className="flex items-center justify-between">
      <div>
        <p className="text-sm font-medium text-gray-600">{title}</p>
        <p className={`text-2xl font-bold ${valueClass ?? 'text-gray-900'}`}>{value}</p>
      </div>
      <div className={`p-3 ${bg} rounded-lg`}>{icon}</div>
    </div>
  </div>
);

export default Drivers;
