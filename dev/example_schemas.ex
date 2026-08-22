defmodule Ecto.ERD.Example do
  @moduledoc false

  def schemas do
    [
      Ecto.ERD.Example.Accounts.ApiKey,
      Ecto.ERD.Example.Accounts.Profile,
      Ecto.ERD.Example.Accounts.User,
      Ecto.ERD.Example.Billing.Plan,
      Ecto.ERD.Example.Billing.Subscription,
      Ecto.ERD.Example.Content.Category,
      Ecto.ERD.Example.Content.Comment,
      Ecto.ERD.Example.Content.Post,
      Ecto.ERD.Example.Content.Revision,
      Ecto.ERD.Example.Content.Tag
    ]
  end
end

defmodule Ecto.ERD.Example.Accounts.Profile do
  @moduledoc false
  use Ecto.Schema

  embedded_schema do
    field(:display_name, :string)
    field(:timezone, :string)
    field(:notifications_enabled, :boolean, default: true)
  end
end

defmodule Ecto.ERD.Example.Content.Revision do
  @moduledoc false
  use Ecto.Schema

  embedded_schema do
    field(:body, :string)
    field(:edited_at, :utc_datetime)
  end
end

defmodule Ecto.ERD.Example.Accounts.User do
  @moduledoc false
  use Ecto.Schema

  schema "users" do
    field(:email, :string)

    field(:role, Ecto.Enum,
      values: [
        :owner,
        :admin,
        :editor,
        :author,
        :reviewer,
        :support,
        :analyst,
        :billing,
        :member,
        :guest,
        :suspended
      ]
    )

    field(:preferences, :map)
    embeds_one(:profile, Ecto.ERD.Example.Accounts.Profile)
    has_one(:api_key, Ecto.ERD.Example.Accounts.ApiKey)
    has_many(:posts, Ecto.ERD.Example.Content.Post, foreign_key: :author_id)
    has_many(:comments, Ecto.ERD.Example.Content.Comment, foreign_key: :author_id)
    has_many(:subscriptions, Ecto.ERD.Example.Billing.Subscription)
    timestamps()
  end
end

defmodule Ecto.ERD.Example.Accounts.ApiKey do
  @moduledoc false
  use Ecto.Schema

  schema "api_keys" do
    field(:token_hash, :binary)
    field(:last_used_at, :utc_datetime_usec)
    belongs_to(:user, Ecto.ERD.Example.Accounts.User)
    timestamps()
  end
end

defmodule Ecto.ERD.Example.Billing.Plan do
  @moduledoc false
  use Ecto.Schema

  schema "plans" do
    field(:name, :string)
    field(:price_cents, :integer)
    field(:features, {:array, :string})
    has_many(:subscriptions, Ecto.ERD.Example.Billing.Subscription)
  end
end

defmodule Ecto.ERD.Example.Billing.Subscription do
  @moduledoc false
  use Ecto.Schema

  schema "subscriptions" do
    field(:status, Ecto.Enum, values: [:trialing, :active, :past_due, :canceled])
    field(:renews_at, :utc_datetime)
    belongs_to(:user, Ecto.ERD.Example.Accounts.User)
    belongs_to(:plan, Ecto.ERD.Example.Billing.Plan)
    timestamps()
  end
end

defmodule Ecto.ERD.Example.Content.Category do
  @moduledoc false
  use Ecto.Schema

  schema "categories" do
    field(:name, :string)
    field(:slug, :string)
    has_many(:posts, Ecto.ERD.Example.Content.Post)
  end
end

defmodule Ecto.ERD.Example.Content.Post do
  @moduledoc false
  use Ecto.Schema

  schema "posts" do
    field(:title, :string)
    field(:body, :string)
    field(:state, Ecto.Enum, values: [:draft, :review, :published, :archived])
    field(:published_at, :utc_datetime_usec)
    field(:metadata, :map)
    belongs_to(:author, Ecto.ERD.Example.Accounts.User)
    belongs_to(:category, Ecto.ERD.Example.Content.Category)
    has_many(:comments, Ecto.ERD.Example.Content.Comment)
    many_to_many(:tags, Ecto.ERD.Example.Content.Tag, join_through: "posts_tags")
    embeds_many(:revisions, Ecto.ERD.Example.Content.Revision)
    timestamps()
  end
end

defmodule Ecto.ERD.Example.Content.Comment do
  @moduledoc false
  use Ecto.Schema

  schema "comments" do
    field(:body, :string)
    field(:visible, :boolean, default: true)
    belongs_to(:post, Ecto.ERD.Example.Content.Post)
    belongs_to(:author, Ecto.ERD.Example.Accounts.User)
    timestamps()
  end
end

defmodule Ecto.ERD.Example.Content.Tag do
  @moduledoc false
  use Ecto.Schema

  schema "tags" do
    field(:name, :string)
    many_to_many(:posts, Ecto.ERD.Example.Content.Post, join_through: "posts_tags")
  end
end
