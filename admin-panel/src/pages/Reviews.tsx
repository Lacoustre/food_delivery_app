import { useState, useEffect, useCallback } from "react";
import { supabase } from "../lib/supabase";
import { Star, MessageSquare, Calendar, User, Reply, Send, Trash2, RotateCcw, Search, Filter, TrendingUp, Award, AlertTriangle, Download } from "lucide-react";
import { toast } from "react-toastify";
import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";
import moment from "moment";

interface ProfileRow {
  name: string | null;
  email: string | null;
}

interface Review {
  id: string;
  user_id: string;
  order_id: string;
  rating: number;
  comment: string | null;
  created_at: string;
  admin_reply: string | null;
  admin_reply_date: string | null;
  /** Approved reviews appear on the website's homepage. */
  is_approved: boolean;
  approved_at: string | null;
  profiles: ProfileRow | ProfileRow[] | null;
}

export default function Reviews() {
  const [selectedRating, setSelectedRating] = useState<number | null>(null);
  const [replyingTo, setReplyingTo] = useState<string | null>(null);
  const [replyText, setReplyText] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isDeleting, setIsDeleting] = useState<string | null>(null);
  const [isClearing, setIsClearing] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState("");
  const [dateFilter, setDateFilter] = useState("all");
  const [sortBy, setSortBy] = useState("newest");
  const [showAnalytics, setShowAnalytics] = useState(false);
  const [selectedReviews, setSelectedReviews] = useState<string[]>([]);
  const [statusFilter, setStatusFilter] = useState<"all" | "pending" | "approved">("all");
  const [approving, setApproving] = useState<string | null>(null);

  const [reviews, setReviews] = useState<Review[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const fetchReviews = useCallback(async () => {
    const { data, error } = await supabase
      .from("order_reviews")
      .select("*, profiles!user_id(name, email)")
      .order("created_at", { ascending: false })
      .limit(100);

    if (error) {
      setError(new Error(error.message));
    } else {
      setError(null);
      setReviews(data as Review[]);
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchReviews();
  }, [fetchReviews]);

  const getCustomerName = (review: Review) => {
    const profile = Array.isArray(review.profiles) ? review.profiles[0] : review.profiles;
    if (profile?.name) return profile.name;
    if (profile?.email) return profile.email.split('@')[0];
    return `Customer ${review.user_id?.slice(-4) || 'Unknown'}`;
  };

  const filteredReviews = reviews.filter((review) => {
    if (statusFilter === "pending" && review.is_approved) return false;
    if (statusFilter === "approved" && !review.is_approved) return false;
    if (selectedRating !== null && Math.round(review.rating || 0) !== selectedRating) {
      return false;
    }

    if (searchTerm) {
      const searchLower = searchTerm.toLowerCase();
      const customerName = getCustomerName(review).toLowerCase();
      const reviewText = (review.comment || '').toLowerCase();
      const orderId = (review.order_id || '').toLowerCase();
      if (!customerName.includes(searchLower) && !reviewText.includes(searchLower) && !orderId.includes(searchLower)) {
        return false;
      }
    }

    if (dateFilter !== "all" && review.created_at) {
      const reviewDate = moment(review.created_at);
      switch (dateFilter) {
        case "today":
          if (!reviewDate.isSame(moment(), "day")) return false;
          break;
        case "week":
          if (!reviewDate.isSame(moment(), "week")) return false;
          break;
        case "month":
          if (!reviewDate.isSame(moment(), "month")) return false;
          break;
      }
    }

    return true;
  }).sort((a, b) => {
    switch (sortBy) {
      case "oldest":
        return new Date(a.created_at).getTime() - new Date(b.created_at).getTime();
      case "highest":
        return (b.rating || 0) - (a.rating || 0);
      case "lowest":
        return (a.rating || 0) - (b.rating || 0);
      default: // newest
        return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
    }
  });

  const averageRating = reviews.length
    ? (reviews.reduce((sum, review) => sum + (review.rating || 0), 0) / reviews.length).toFixed(1)
    : "0.0";

  const ratingCounts = [5, 4, 3, 2, 1].map(rating => ({
    rating,
    count: reviews.filter((r) => Math.round(r.rating || 0) === rating).length
  }));

  const analytics = {
    totalReviews: reviews.length,
    averageRating: parseFloat(averageRating),
    positiveReviews: reviews.filter(r => (r.rating || 0) >= 4).length,
    negativeReviews: reviews.filter(r => (r.rating || 0) <= 2).length,
    repliedReviews: reviews.filter(r => r.admin_reply).length,
    recentReviews: reviews.filter(r =>
      r.created_at && moment(r.created_at).isAfter(moment().subtract(7, 'days'))
    ).length
  };

  const formatDate = (value: string | null) => {
    if (!value) return "Unknown date";
    const date = new Date(value);
    return date.toLocaleDateString() + " " + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  const exportReviewsToPDF = () => {
    const pdfDoc = new jsPDF();
    pdfDoc.setFontSize(24);
    pdfDoc.text("Taste of African Cuisine", 14, 20);
    pdfDoc.setFontSize(16);
    pdfDoc.text("Customer Reviews Report", 14, 35);
    pdfDoc.setFontSize(12);
    pdfDoc.text(`Generated: ${moment().format("MMMM D, YYYY")}`, 14, 45);
    pdfDoc.text(`Average Rating: ${averageRating}/5.0 (${reviews.length} reviews)`, 14, 55);

    autoTable(pdfDoc, {
      startY: 65,
      head: [["Customer", "Rating", "Review", "Date", "Admin Reply"]],
      body: filteredReviews.map(review => [
        getCustomerName(review),
        `${review.rating}/5`,
        (review.comment || 'No comment').substring(0, 100) + ((review.comment?.length || 0) > 100 ? '...' : ''),
        formatDate(review.created_at),
        review.admin_reply ? 'Yes' : 'No'
      ]),
    });

    pdfDoc.save(`Reviews_Report_${moment().format("YYYY_MM_DD")}.pdf`);
  };

  const handleBulkDelete = async () => {
    if (selectedReviews.length === 0) {
      toast.error("Please select reviews first");
      return;
    }

    if (!confirm(`Delete ${selectedReviews.length} selected reviews?`)) return;

    try {
      const { error } = await supabase.from("order_reviews").delete().in("id", selectedReviews);
      if (error) throw error;
      toast.success(`Deleted ${selectedReviews.length} reviews`);
      setSelectedReviews([]);
      fetchReviews();
    } catch {
      toast.error("Failed to delete reviews");
    }
  };

  const handleSelectAll = () => {
    if (selectedReviews.length === filteredReviews.length) {
      setSelectedReviews([]);
    } else {
      setSelectedReviews(filteredReviews.map(r => r.id));
    }
  };

  const renderStars = (rating: number) => {
    return Array.from({ length: 5 }, (_, i) => (
      <Star
        key={i}
        className={`w-4 h-4 ${
          i < rating ? "text-yellow-400 fill-current" : "text-gray-300"
        }`}
      />
    ));
  };

  const handleReplySubmit = async (reviewId: string) => {
    if (!replyText.trim()) {
      toast.error('Please enter a reply message');
      return;
    }

    setIsSubmitting(true);
    try {
      const { error } = await supabase
        .from("order_reviews")
        .update({ admin_reply: replyText.trim(), admin_reply_date: new Date().toISOString() })
        .eq("id", reviewId);
      if (error) throw error;

      setReplyingTo(null);
      setReplyText('');
      toast.success('Reply sent successfully!');
      fetchReviews();
    } catch (err) {
      console.error('Error sending reply:', err);
      toast.error('Failed to send reply: ' + (err instanceof Error ? err.message : String(err)));
    } finally {
      setIsSubmitting(false);
    }
  };

  // Approving publishes a review on the website's homepage (first name and
  // last initial only). It doesn't touch Google: a business can't post reviews
  // there for a customer, so the site invites every reviewer to do it.
  const handleApproval = async (review: Review) => {
    setApproving(review.id);
    try {
      const { data, error } = await supabase
        .from("order_reviews")
        .update({ is_approved: !review.is_approved })
        .eq("id", review.id)
        .select("id");
      if (error) throw error;
      // Row-level security refuses silently — no error, nothing updated.
      if (!data?.length) throw new Error("update not permitted");
      toast.success(review.is_approved ? "Removed from the website" : "Published on the website");
      fetchReviews();
    } catch (err) {
      console.error("Error updating approval:", err);
      toast.error("Could not update the review");
    } finally {
      setApproving(null);
    }
  };

  const handleDeleteReview = async (reviewId: string) => {
    if (!confirm('Are you sure you want to delete this review? This action cannot be undone.')) {
      return;
    }

    setIsDeleting(reviewId);
    try {
      const { error } = await supabase.from("order_reviews").delete().eq("id", reviewId);
      if (error) throw error;
      toast.success('Review deleted successfully!');
      fetchReviews();
    } catch (err) {
      console.error('Error deleting review:', err);
      toast.error('Failed to delete review: ' + (err instanceof Error ? err.message : String(err)));
    } finally {
      setIsDeleting(null);
    }
  };

  const handleClearReply = async (reviewId: string) => {
    if (!confirm('Are you sure you want to clear your reply to this review?')) {
      return;
    }

    setIsClearing(reviewId);
    try {
      const { error } = await supabase
        .from("order_reviews")
        .update({ admin_reply: null, admin_reply_date: null })
        .eq("id", reviewId);
      if (error) throw error;
      toast.success('Reply cleared successfully!');
      fetchReviews();
    } catch (err) {
      console.error('Error clearing reply:', err);
      toast.error('Failed to clear reply: ' + (err instanceof Error ? err.message : String(err)));
    } finally {
      setIsClearing(null);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-orange-500"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 rounded-lg p-4">
        <p className="text-red-600">Error loading reviews: {error.message}</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Customer Reviews</h1>
          <p className="text-gray-600">Monitor and respond to customer feedback.</p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={() => setShowAnalytics(!showAnalytics)}
            className="bg-purple-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-purple-700 transition-colors flex items-center gap-2"
          >
            <TrendingUp className="w-4 h-4" />
            Analytics
          </button>
          <button
            onClick={exportReviewsToPDF}
            className="bg-green-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-green-700 transition-colors flex items-center gap-2"
          >
            <Download className="w-4 h-4" />
            Export PDF
          </button>
        </div>
      </div>

      {/* Analytics Dashboard */}
      {showAnalytics && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">Review Analytics</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-6 gap-4">
            <div className="bg-blue-50 rounded-lg p-4">
              <div className="flex items-center gap-2">
                <MessageSquare className="w-5 h-5 text-blue-600" />
                <div>
                  <p className="text-sm font-medium text-gray-600">Total</p>
                  <p className="text-xl font-bold text-gray-900">{analytics.totalReviews}</p>
                </div>
              </div>
            </div>
            <div className="bg-yellow-50 rounded-lg p-4">
              <div className="flex items-center gap-2">
                <Star className="w-5 h-5 text-yellow-600" />
                <div>
                  <p className="text-sm font-medium text-gray-600">Avg Rating</p>
                  <p className="text-xl font-bold text-gray-900">{analytics.averageRating.toFixed(1)}</p>
                </div>
              </div>
            </div>
            <div className="bg-green-50 rounded-lg p-4">
              <div className="flex items-center gap-2">
                <Award className="w-5 h-5 text-green-600" />
                <div>
                  <p className="text-sm font-medium text-gray-600">Positive</p>
                  <p className="text-xl font-bold text-gray-900">{analytics.positiveReviews}</p>
                </div>
              </div>
            </div>
            <div className="bg-red-50 rounded-lg p-4">
              <div className="flex items-center gap-2">
                <AlertTriangle className="w-5 h-5 text-red-600" />
                <div>
                  <p className="text-sm font-medium text-gray-600">Negative</p>
                  <p className="text-xl font-bold text-gray-900">{analytics.negativeReviews}</p>
                </div>
              </div>
            </div>
            <div className="bg-purple-50 rounded-lg p-4">
              <div className="flex items-center gap-2">
                <Reply className="w-5 h-5 text-purple-600" />
                <div>
                  <p className="text-sm font-medium text-gray-600">Replied</p>
                  <p className="text-xl font-bold text-gray-900">{analytics.repliedReviews}</p>
                </div>
              </div>
            </div>
            <div className="bg-orange-50 rounded-lg p-4">
              <div className="flex items-center gap-2">
                <Calendar className="w-5 h-5 text-orange-600" />
                <div>
                  <p className="text-sm font-medium text-gray-600">This Week</p>
                  <p className="text-xl font-bold text-gray-900">{analytics.recentReviews}</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Search and Filters */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div className="flex flex-col lg:flex-row gap-4 items-start lg:items-center justify-between">
          <div className="flex flex-col sm:flex-row gap-4 flex-1">
            <div className="relative flex-1 max-w-md">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
              <input
                type="text"
                placeholder="Search reviews by customer, order ID, or content..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors"
              />
            </div>

            <div className="flex items-center gap-2">
              <Calendar className="text-gray-400 w-5 h-5" />
              <select
                value={dateFilter}
                onChange={(e) => setDateFilter(e.target.value)}
                className="border border-gray-300 px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors"
              >
                <option value="all">All Time</option>
                <option value="today">Today</option>
                <option value="week">This Week</option>
                <option value="month">This Month</option>
              </select>
            </div>

            <div className="flex items-center gap-2">
              <Filter className="text-gray-400 w-5 h-5" />
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value)}
                className="border border-gray-300 px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors"
              >
                <option value="newest">Newest First</option>
                <option value="oldest">Oldest First</option>
                <option value="highest">Highest Rating</option>
                <option value="lowest">Lowest Rating</option>
              </select>
            </div>
          </div>

          {(searchTerm || dateFilter !== "all") && (
            <button
              onClick={() => {
                setSearchTerm("");
                setDateFilter("all");
              }}
              className="text-sm text-gray-600 hover:text-gray-800 underline"
            >
              Clear filters
            </button>
          )}
        </div>
      </div>

      {/* Bulk Actions */}
      {selectedReviews.length > 0 && (
        <div className="bg-red-50 border border-red-200 rounded-xl p-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <span className="text-sm font-medium text-red-900">
                {selectedReviews.length} review(s) selected
              </span>
              <button
                onClick={() => setSelectedReviews([])}
                className="text-sm text-red-600 hover:text-red-800"
              >
                Clear selection
              </button>
            </div>
            <button
              onClick={handleBulkDelete}
              className="px-4 py-2 bg-red-600 text-white text-sm rounded-lg hover:bg-red-700 flex items-center gap-2"
            >
              <Trash2 className="w-4 h-4" />
              Delete Selected
            </button>
          </div>
        </div>
      )}

      {/* Rating Overview */}
      <div className="bg-white rounded-lg shadow p-6">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="text-center">
            <div className="text-4xl font-bold text-gray-900 mb-2">{averageRating}</div>
            <div className="flex justify-center mb-2">
              {renderStars(Math.round(parseFloat(averageRating)))}
            </div>
            <p className="text-gray-600">Average Rating</p>
          </div>

          <div className="space-y-2">
            {ratingCounts.map(({ rating, count }) => (
              <div key={`rating-${rating}`} className="flex items-center space-x-2">
                <span className="text-sm font-medium w-8">{rating}★</span>
                <div className="flex-1 bg-gray-200 rounded-full h-2">
                  <div
                    className="bg-yellow-400 h-2 rounded-full"
                    style={{
                      width: `${reviews.length ? (count / reviews.length) * 100 : 0}%`
                    }}
                  ></div>
                </div>
                <span className="text-sm text-gray-600 w-8">{count}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Results Summary */}
      <div className="flex items-center justify-between">
        <p className="text-sm text-gray-600">
          Showing {filteredReviews.length} of {reviews.length} reviews
        </p>
        {filteredReviews.length > 0 && (
          <button
            onClick={handleSelectAll}
            className="text-sm text-blue-600 hover:text-blue-800 flex items-center gap-1"
          >
            {selectedReviews.length === filteredReviews.length ? 'Deselect All' : 'Select All'}
          </button>
        )}
      </div>

      {/* Approval */}
      <div className="flex flex-wrap gap-2">
        {([
          ["all", "All"],
          ["pending", `Awaiting approval (${reviews.filter(r => !r.is_approved).length})`],
          ["approved", `On the website (${reviews.filter(r => r.is_approved).length})`],
        ] as const).map(([value, label]) => (
          <button
            key={value}
            onClick={() => setStatusFilter(value)}
            className={`px-4 py-2 rounded-lg text-sm font-medium ${
              statusFilter === value ? "bg-gray-900 text-white" : "bg-gray-100 text-gray-700 hover:bg-gray-200"
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {/* Filter Buttons */}
      <div className="flex flex-wrap gap-2">
        <button
          onClick={() => setSelectedRating(null)}
          className={`px-4 py-2 rounded-lg text-sm font-medium ${
            selectedRating === null
              ? "bg-orange-500 text-white"
              : "bg-gray-100 text-gray-700 hover:bg-gray-200"
          }`}
        >
          All Reviews
        </button>
        {[5, 4, 3, 2, 1].map(rating => (
          <button
            key={`filter-${rating}`}
            onClick={() => setSelectedRating(rating)}
            className={`px-4 py-2 rounded-lg text-sm font-medium flex items-center space-x-1 ${
              selectedRating === rating
                ? "bg-orange-500 text-white"
                : "bg-gray-100 text-gray-700 hover:bg-gray-200"
            }`}
          >
            <span>{rating}</span>
            <Star className="w-3 h-3" />
          </button>
        ))}
      </div>

      {/* Reviews List */}
      <div className="space-y-4">
        {filteredReviews.length === 0 ? (
          <div className="text-center py-12">
            <MessageSquare className="w-12 h-12 text-gray-400 mx-auto mb-4" />
            <p className="text-gray-500">
              {selectedRating ? `No ${selectedRating}-star reviews found` : "No reviews yet"}
            </p>
          </div>
        ) : (
          filteredReviews.map((review, index) => (
            <div key={review.id || `review-${index}`} className="bg-white rounded-lg shadow p-6">
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center space-x-3">
                  <input
                    type="checkbox"
                    checked={selectedReviews.includes(review.id)}
                    onChange={(e) => {
                      if (e.target.checked) {
                        setSelectedReviews([...selectedReviews, review.id]);
                      } else {
                        setSelectedReviews(selectedReviews.filter(id => id !== review.id));
                      }
                    }}
                    className="rounded border-gray-300"
                  />
                  <div className="w-10 h-10 bg-orange-100 rounded-full flex items-center justify-center">
                    <User className="w-5 h-5 text-orange-600" />
                  </div>
                  <div>
                    <h3 className="font-medium text-gray-900">
                      {getCustomerName(review)}
                    </h3>
                    <p className="text-sm text-gray-500">Order: {review.order_id}</p>
                  </div>
                </div>
                <div className="flex items-center space-x-2">
                  <div className="flex">{renderStars(review.rating)}</div>
                  <span className="text-sm text-gray-600 flex items-center">
                    <Calendar className="w-3 h-3 mr-1" />
                    {formatDate(review.created_at)}
                  </span>
                  {review.is_approved ? (
                    <span className="inline-flex items-center gap-2 ml-2 text-xs">
                      <span data-approval className="px-2.5 py-1 rounded-full bg-green-100 text-green-800 font-semibold whitespace-nowrap">
                        On the website
                      </span>
                      <button
                        onClick={() => handleApproval(review)}
                        disabled={approving === review.id}
                        className="text-gray-500 hover:text-gray-800 underline disabled:opacity-50"
                      >
                        Remove
                      </button>
                    </span>
                  ) : (
                    <button
                      data-approval
                      onClick={() => handleApproval(review)}
                      disabled={approving === review.id}
                      className="ml-2 px-3 py-1 rounded-lg bg-blue-600 text-white text-xs font-semibold hover:bg-blue-700 disabled:opacity-50"
                    >
                      {approving === review.id ? "Approving..." : "Approve"}
                    </button>
                  )}
                  <div className="flex items-center space-x-1 ml-2">
                    {review.admin_reply && (
                      <button
                        onClick={() => handleClearReply(review.id)}
                        disabled={isClearing === review.id}
                        className="p-1 text-yellow-600 hover:text-yellow-700 hover:bg-yellow-50 rounded transition-colors"
                        title="Clear Reply"
                      >
                        <RotateCcw className="w-4 h-4" />
                      </button>
                    )}
                    <button
                      onClick={() => handleDeleteReview(review.id)}
                      disabled={isDeleting === review.id}
                      className="p-1 text-red-600 hover:text-red-700 hover:bg-red-50 rounded transition-colors"
                      title="Delete Review"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>

              <div className="bg-gray-50 rounded-lg p-4 space-y-4">
                <div>
                  <p className="text-gray-700 font-medium mb-1">Customer Review:</p>
                  <p className="text-gray-700">
                    {review.comment || "No written review provided."}
                  </p>
                </div>

                {/* Admin Reply Section */}
                {review.admin_reply ? (
                  <div className="border-l-4 border-orange-500 pl-4 bg-orange-50 rounded-r-lg p-3">
                    <div className="flex items-center gap-2 mb-2">
                      <Reply className="w-4 h-4 text-orange-600" />
                      <span className="text-sm font-medium text-orange-800">Admin Response</span>
                      <span className="text-xs text-orange-600">
                        {review.admin_reply_date ? formatDate(review.admin_reply_date) : ''}
                      </span>
                    </div>
                    <p className="text-orange-900">{review.admin_reply}</p>
                  </div>
                ) : (
                  <div className="pt-2 border-t border-gray-200">
                    {replyingTo === review.id ? (
                      <div className="space-y-3">
                        <textarea
                          value={replyText}
                          onChange={(e) => setReplyText(e.target.value)}
                          placeholder="Write your response to this review..."
                          className="w-full p-3 border border-gray-300 rounded-lg resize-none focus:ring-2 focus:ring-orange-500 focus:border-orange-500"
                          rows={3}
                          disabled={isSubmitting}
                        />
                        <div className="flex gap-2">
                          <button
                            onClick={() => handleReplySubmit(review.id)}
                            disabled={!replyText.trim() || isSubmitting}
                            className="flex items-center gap-2 px-4 py-2 bg-orange-500 text-white rounded-lg hover:bg-orange-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                          >
                            <Send className="w-4 h-4" />
                            {isSubmitting ? 'Sending...' : 'Send Reply'}
                          </button>
                          <button
                            onClick={() => {
                              setReplyingTo(null);
                              setReplyText('');
                            }}
                            disabled={isSubmitting}
                            className="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
                          >
                            Cancel
                          </button>
                        </div>
                      </div>
                    ) : (
                      <button
                        onClick={() => setReplyingTo(review.id)}
                        className="flex items-center gap-2 px-3 py-2 text-orange-600 hover:text-orange-700 hover:bg-orange-50 rounded-lg transition-colors text-sm font-medium"
                      >
                        <Reply className="w-4 h-4" />
                        Reply to Review
                      </button>
                    )}
                  </div>
                )}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
