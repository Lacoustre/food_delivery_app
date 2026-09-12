import { useState, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "../lib/supabase";
import Loader from "../components/Loader";
import { toast } from "react-toastify";
import { Eye, EyeOff } from "lucide-react";
import logo from "../assets/images/logo.png";

/**
 * Where the admin reset link lands.
 *
 * The link carries its tokens in the URL fragment; supabase-js reads them on
 * load and turns them into a session, which is what allows updateUser to set a
 * password without knowing the old one. That runs asynchronously and can
 * finish before this mounts, so the session is both asked for and waited for.
 *
 * Public on purpose — it sits outside ProtectedRoute, because somebody who has
 * lost their password cannot get past an admin check to reach it.
 */
type Phase = "checking" | "ready" | "invalid" | "done";

function fragmentError(): string | null {
  const params = new URLSearchParams(window.location.hash.replace(/^#/, ""));
  if (!params.get("error")) return null;
  return params.get("error_code") === "otp_expired"
    ? "That link has expired. Reset links are only good for a short while."
    : params.get("error_description")?.replace(/\+/g, " ") ||
        "That link is no longer valid.";
}

export default function ResetPassword() {
  const [phase, setPhase] = useState<Phase>("checking");
  const [linkError, setLinkError] = useState<string | null>(null);
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const navigate = useNavigate();
  const settled = useRef(false);

  useEffect(() => {
    const fromFragment = fragmentError();
    if (fromFragment) {
      settled.current = true;
      setLinkError(fromFragment);
      setPhase("invalid");
      return;
    }

    const ready = () => {
      if (settled.current) return;
      settled.current = true;
      setPhase("ready");
    };

    supabase.auth.getSession().then(({ data }) => {
      if (data.session) ready();
    });

    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session) ready();
    });

    const timer = setTimeout(() => {
      if (!settled.current) {
        settled.current = true;
        setPhase("invalid");
      }
    }, 4000);

    return () => {
      clearTimeout(timer);
      listener.subscription.unsubscribe();
    };
  }, []);

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();

    if (password.length < 8) {
      toast.error("Use at least 8 characters.", { position: "top-right", autoClose: 3000 });
      return;
    }
    if (password !== confirm) {
      toast.error("The two passwords do not match.", { position: "top-right", autoClose: 3000 });
      return;
    }

    setIsSaving(true);
    try {
      const { error } = await supabase.auth.updateUser({ password });
      if (error) throw error;
      setPhase("done");
      toast.success("Password updated.", { position: "top-right", autoClose: 3000 });
      // The recovery session is a real session, so there is nothing further to
      // sign in to — send them straight into the dashboard.
      setTimeout(() => navigate("/"), 1200);
    } catch (error: unknown) {
      const msg =
        error && typeof error === "object" && "message" in error
          ? String((error as { message: unknown }).message)
          : "Could not update the password.";
      toast.error(msg, { position: "top-right", autoClose: 4000 });
    } finally {
      setIsSaving(false);
    }
  };

  if (phase === "checking") {
    return <Loader />;
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-100 px-4">
      <div className="w-full max-w-md bg-white rounded-xl shadow-lg p-8">
        <img src={logo} alt="Taste of African Cuisine" className="w-24 h-24 mx-auto mb-6 rounded-full object-cover shadow-lg" />

        {phase === "invalid" && (
          <div className="text-center">
            <h1 className="text-xl font-semibold text-gray-900 mb-3">
              This link has expired
            </h1>
            <p className="text-gray-600 text-sm leading-relaxed mb-6">
              {linkError ||
                "Reset links can only be used once, and not long after they are sent. Ask for a fresh one from the sign-in page."}
            </p>
            <button
              onClick={() => navigate("/login")}
              className="w-full py-3 bg-gradient-to-r from-amber-600 to-orange-600 text-white rounded-xl font-bold hover:from-amber-700 hover:to-orange-700 transition-all shadow-lg"
            >
              Back to sign in
            </button>
          </div>
        )}

        {phase === "done" && (
          <div className="text-center">
            <h1 className="text-xl font-semibold text-gray-900 mb-3">Password updated</h1>
            <p className="text-gray-600 text-sm">Taking you to the dashboard…</p>
          </div>
        )}

        {phase === "ready" && (
          <>
            <h1 className="text-xl font-semibold text-gray-900 mb-1 text-center">
              Set a new password
            </h1>
            <p className="text-gray-600 text-sm mb-6 text-center">
              This is the password for the admin dashboard.
            </p>

            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  New password
                </label>
                <div className="relative">
                  <input
                    type={showPassword ? "text" : "password"}
                    autoComplete="new-password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                    placeholder="At least 8 characters"
                    className="w-full px-4 py-3 pr-11 border border-gray-300 rounded-lg focus:ring-2 focus:ring-amber-500 focus:border-amber-500 outline-none"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                  >
                    {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Confirm password
                </label>
                <input
                  type={showPassword ? "text" : "password"}
                  autoComplete="new-password"
                  value={confirm}
                  onChange={(e) => setConfirm(e.target.value)}
                  required
                  placeholder="Type it again"
                  className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-amber-500 focus:border-amber-500 outline-none"
                />
              </div>

              <button
                type="submit"
                disabled={isSaving}
                className="w-full py-3 bg-gradient-to-r from-amber-600 to-orange-600 text-white rounded-xl font-bold hover:from-amber-700 hover:to-orange-700 transition-all shadow-lg disabled:opacity-50"
              >
                {isSaving ? "Saving…" : "Save password"}
              </button>
            </form>
          </>
        )}
      </div>
    </div>
  );
}
