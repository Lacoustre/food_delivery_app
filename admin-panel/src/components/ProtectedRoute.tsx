import { type ReactNode, useEffect, useState } from "react";
import { Navigate } from "react-router-dom";
import { supabase } from "../lib/supabase";
import Loader from "./Loader";

interface ProtectedRouteProps {
  children: ReactNode;
}

export default function ProtectedRoute({ children }: ProtectedRouteProps) {
  const [isLoading, setIsLoading] = useState(true);
  const [isAdmin, setIsAdmin] = useState(false);

  useEffect(() => {
    let unsubscribed = false;

    const checkAdmin = async (userId: string | undefined) => {
      if (!userId) {
        if (!unsubscribed) {
          setIsAdmin(false);
          setIsLoading(false);
        }
        return;
      }

      // Session alone isn't enough — only role === 'admin' may see this
      // dashboard. Any authenticated Supabase user (e.g. a customer
      // account) must be rejected here, not just at the login form.
      const { data: profile } = await supabase
        .from("profiles")
        .select("role")
        .eq("id", userId)
        .single();

      if (!unsubscribed) {
        setIsAdmin(profile?.role === "admin");
        setIsLoading(false);
      }
    };

    supabase.auth.getSession().then(({ data }) => {
      checkAdmin(data.session?.user.id);
    });

    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      setIsLoading(true);
      checkAdmin(session?.user.id);
    });

    return () => {
      unsubscribed = true;
      listener.subscription.unsubscribe();
    };
  }, []);

  if (isLoading) {
    return <Loader />;
  }

  if (!isAdmin) {
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
}
